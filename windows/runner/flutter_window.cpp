#include "flutter_window.h"

#include <optional>
#include <flutter/standard_method_codec.h>
#include "resource.h"

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  download_job_ = CreateJobObjectW(nullptr, nullptr);
  if (download_job_) {
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{};
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    SetInformationJobObject(download_job_, JobObjectExtendedLimitInformation, &limits, sizeof(limits));
  }
  download_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "noor/download_tray", &flutter::StandardMethodCodec::GetInstance());
  download_channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() == "trackProcess") {
      const auto* pid = std::get_if<int32_t>(call.arguments());
      HANDLE process = pid ? OpenProcess(PROCESS_SET_QUOTA | PROCESS_TERMINATE, FALSE, static_cast<DWORD>(*pid)) : nullptr;
      bool assigned = process && download_job_ && AssignProcessToJobObject(download_job_, process);
      if (process) CloseHandle(process);
      if (assigned) result->Success(); else result->Error("process", "Could not supervise download engine");
      return;
    }
    if (call.method_name() != "update") { result->NotImplemented(); return; }
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!args) { result->Error("arguments", "Missing state"); return; }
    auto active = std::get<bool>(args->at(flutter::EncodableValue("active")));
    download_paused_ = std::get<bool>(args->at(flutter::EncodableValue("paused")));
    auto text = std::get<std::string>(args->at(flutter::EncodableValue("text")));
    tray_.cbSize = sizeof(tray_); tray_.hWnd = GetHandle(); tray_.uID = 1;
    tray_.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
    tray_.uCallbackMessage = WM_APP + 41;
    tray_.hIcon = LoadIcon(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON));
    MultiByteToWideChar(CP_UTF8, 0, text.c_str(), -1, tray_.szTip, 128);
    if (!tray_added_ && active) {
      tray_.uFlags |= NIF_INFO;
      wcscpy_s(tray_.szInfoTitle, L"NOOR");
      wcscpy_s(tray_.szInfo, L"Download continues in the background. Right-click for Pause, Resume or Cancel.");
      tray_.dwInfoFlags = NIIF_INFO;
      tray_added_ = Shell_NotifyIconW(NIM_ADD, &tray_) != FALSE;
    } else if (tray_added_) { Shell_NotifyIconW(NIM_MODIFY, &tray_); }
    result->Success();
  });
  media_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "noor/media_access", &flutter::StandardMethodCodec::GetInstance());
  media_channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() == "pending") {
      auto pending = pending_media_; pending_media_.clear();
      result->Success(flutter::EncodableValue(pending));
    } else result->NotImplemented();
  });
  DragAcceptFiles(GetHandle(), TRUE);
  int argc = 0;
  LPWSTR* argv = CommandLineToArgvW(GetCommandLineW(), &argc);
  std::vector<std::wstring> paths;
  for (int i = 1; argv && i < argc; ++i) paths.emplace_back(argv[i]);
  if (argv) LocalFree(argv);
  QueueMedia(paths);
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (tray_added_) Shell_NotifyIconW(NIM_DELETE, &tray_);
  media_channel_.reset();
  download_channel_.reset();
  if (download_job_) { CloseHandle(download_job_); download_job_ = nullptr; }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::QueueMedia(const std::vector<std::wstring>& files) {
  for (const auto& file : files) {
    if (file.empty() || GetFileAttributesW(file.c_str()) == INVALID_FILE_ATTRIBUTES) continue;
    int length = WideCharToMultiByte(CP_UTF8, 0, file.c_str(), -1, nullptr, 0, nullptr, nullptr);
    std::string value(length, '\0');
    WideCharToMultiByte(CP_UTF8, 0, file.c_str(), -1, value.data(), length, nullptr, nullptr);
    value.pop_back(); pending_media_.emplace_back(value);
  }
  if (!pending_media_.empty() && media_channel_) media_channel_->InvokeMethod("available", nullptr);
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_DROPFILES) {
    HDROP drop = reinterpret_cast<HDROP>(wparam);
    UINT count = DragQueryFileW(drop, 0xFFFFFFFF, nullptr, 0);
    std::vector<std::wstring> files;
    for (UINT i = 0; i < count; ++i) {
      UINT length = DragQueryFileW(drop, i, nullptr, 0);
      std::wstring path(length + 1, L'\0');
      DragQueryFileW(drop, i, path.data(), length + 1); path.resize(length); files.push_back(path);
    }
    DragFinish(drop); QueueMedia(files); return 0;
  }
  if (message == WM_COPYDATA) {
    auto data = reinterpret_cast<COPYDATASTRUCT*>(lparam);
    if (data && data->dwData == 0x4E4F4F52 && data->cbData >= sizeof(wchar_t) && data->cbData < 65536) {
      std::wstring command(static_cast<const wchar_t*>(data->lpData), data->cbData / sizeof(wchar_t));
      int argc = 0; LPWSTR* argv = CommandLineToArgvW(command.c_str(), &argc);
      std::vector<std::wstring> files;
      for (int i = 1; argv && i < argc; ++i) files.emplace_back(argv[i]);
      if (argv) LocalFree(argv);
      QueueMedia(files); ShowWindow(hwnd, SW_SHOW); SetForegroundWindow(hwnd); return TRUE;
    }
  }
  if (message == WM_APP + 41) {
    if (lparam == WM_LBUTTONUP || lparam == WM_LBUTTONDBLCLK) {
      ShowWindow(hwnd, SW_SHOW); SetForegroundWindow(hwnd);
    } else if (lparam == WM_RBUTTONUP) {
      HMENU menu = CreatePopupMenu();
      AppendMenuW(menu, MF_STRING, 1, L"Open NOOR");
      AppendMenuW(menu, MF_STRING, 2, download_paused_ ? L"Resume download" : L"Pause download");
      AppendMenuW(menu, MF_STRING, 3, L"Cancel download");
      POINT cursor; GetCursorPos(&cursor); SetForegroundWindow(hwnd);
      int selected = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_NONOTIFY, cursor.x, cursor.y, 0, hwnd, nullptr);
      DestroyMenu(menu);
      if (selected == 1) { ShowWindow(hwnd, SW_SHOW); SetForegroundWindow(hwnd); }
      if (selected == 2) download_channel_->InvokeMethod(download_paused_ ? "resume" : "pause", nullptr);
      if (selected == 3) download_channel_->InvokeMethod("cancel", nullptr);
    }
    return 0;
  }
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
