# Music separation (Windows) — 2026-11-07

Optional feature: from the Library's "more" menu, **Remove music** (keep
voices: speech, recitation, singing) or **Music only** (drop voices). It
makes a new copy in `Downloads\NOOR` and adds it to the library; the
original file is not changed. Video keeps its picture and subtitles as they
are (stream copy); only the audio is replaced (AAC 192k, MKV). Audio files
become MP3 256k. One job at a time, in the background, with progress and
Cancel. Windows only for now.

## Engine

- **demucs.cpp** ([sevagh/demucs.cpp](https://github.com/sevagh/demucs.cpp),
  MIT) at commit `4edae497a114de1ccb17ac9b4a2b8fc0144714d7`: a C++ port of
  Meta's Demucs v4 (hybrid transformer). No Python at runtime.
- Model **htdemucs** (4 sources: drums, bass, other, vocals), converted on
  this machine from **Meta's official weights** (`955717e8-8726e21a.th`,
  downloaded by Demucs from `dl.fbaipublicfiles.com`; Demucs is MIT,
  "Copyright (c) Meta"). Pre-converted third-party weights were not used.
  Result: 533 tensors, 80.1 MB float16 — the same count and size demucs.cpp
  documents for this model.
- Remove music = the vocals stem. Music only = drums + bass + other.

## Build — `tool/setup_windows_demucs.ps1`

1. Clones demucs.cpp at the commit above and applies
   `tool/demucs/demucs_mt-windows.patch` (MSVC: `std::filesystem::path` is
   wide, so the output path needs `.string()`).
2. Builds `demucs_mt` with `tool/demucs/CMakeLists.txt` (MSVC, `/O2
   /arch:AVX2 /openmp`, static C++ runtime). Upstream's CMakeLists targets
   GCC/Linux; its `-march=native` would tie the binary to the build CPU.
   AVX2 needs a 2013-or-later x64 CPU.
3. Converts the weights with `tool/demucs/convert_from_model.py`: it takes
   the tensors from the model Demucs already loaded and writes demucs.cpp's
   ggml format. Upstream's script re-loads the checkpoint with
   `torch.load`, which PyTorch ≥ 2.6 refuses (weights_only); forcing a full
   unpickle was avoided. Python packages are pinned in
   `tool/demucs/requirements.txt` (CPU PyTorch) and used only here.
4. Installs into `engines\demucs`: `demucs.exe`, `htdemucs-4s-f16.bin`,
   `vcomp140.dll` (MSVC OpenMP runtime, redistributable) and the licenses
   (demucs.cpp MIT, Demucs MIT, Eigen MPL-2.0, libnyquist BSD-2).

## Speed and memory (i7-14700F, 28 threads, 256 s of audio)

| demucs_mt workers × OpenMP threads | Time |
|---|---|
| 8 × 3 | **387 s** |
| 8 × default | 318 s / 444 s (unstable) |
| 8 × 1, 16 × 1 | ~605 s |
| 4 × 6 | 953 s |

A worker needs about 100 s per ~7.8 s model window; wall time is about
`ceil(windows / workers) × 100 s`, so the app uses one worker per window,
up to 8 (half the logical CPUs on smaller machines), with
`OMP_NUM_THREADS = CPUs / workers` (≤ 4). 8 workers used ~4.2–4.6 GB RAM.
Timings vary on hybrid (P/E core) CPUs. In the app, 16 s took ~100 s and
a 15 s video ~170 s.

Quality check on the 256 s sample: the four stems summed back to the
original within −55.7 dB against −23.9 dB (about 32 dB below the signal).

## Limits

- Windows only. Android would need a separate (mobile) engine.
- Slow on CPU: roughly 1.5× the duration for a 4-minute song on the
  machine above; longer on smaller CPUs. Needs several GB of free RAM.
- Separation quality depends on the recording; some music can remain in
  "Remove music", and some voice in "Music only".
- Files with no audio stream are refused with a message.
