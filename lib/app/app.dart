import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../data/library_controller.dart';
import '../data/media_access.dart';
import '../data/online_media_service.dart';
import 'l10n/gen/app_localizations.dart';
import 'player_route.dart';
import 'router.dart';
import 'settings.dart';
import 'theme.dart';

class NoorApp extends StatefulWidget {
  const NoorApp({super.key, required this.settings, required this.library});
  final AppSettings settings;
  final LibraryController library;

  @override
  State<NoorApp> createState() => _NoorAppState();
}

class _NoorAppState extends State<NoorApp>
    with WidgetsBindingObserver, WindowListener {
  bool _closing = false;
  Timer? _reconcileTimer;
  bool _receivingMedia = false;
  late final _online = OnlineMediaService(widget.library);
  late final _router = buildRouter(widget.settings, widget.library, _online);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    mediaAccessChannel.setMethodCallHandler((call) async {
      if (call.method == 'available') await _incomingMedia();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_incomingMedia());
      unawaited(_online.reconcileDownloads());
    });
    _reconcileTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(_online.reconcileDownloads()),
    );
    unawaited(
      _online.loadHistory().catchError((Object error) {
        debugPrint('Download recovery unavailable: $error');
      }),
    );
    if (Platform.isWindows) {
      windowManager.addListener(this);
      unawaited(windowManager.setPreventClose(true));
    }
  }

  Future<void> _incomingMedia() async {
    if (_receivingMedia || !mounted) return;
    _receivingMedia = true;
    try {
      final entries =
          await mediaAccessChannel.invokeListMethod<dynamic>('pending') ?? [];
      final items = await importMediaReferences(widget.library, entries);
      if (mounted && items.isNotEmpty) {
        openPlayerRoute(_router, items.first.path);
      }
    } catch (error) {
      debugPrint('Open media: $error');
    } finally {
      _receivingMedia = false;
    }
  }

  @override
  void onWindowClose() async {
    if (_online.hasTransfer) {
      await windowManager.hide();
      return;
    }
    if (_closing) return;
    _closing = true;
    await windowManager.hide();
    widget.library.capturePlaybackProgress?.call();
    try {
      await Future.wait([widget.library.flush(), widget.settings.flush()])
          .timeout(const Duration(milliseconds: 500));
    } catch (_) {}
    await windowManager.destroy();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_online.reconcileDownloads());
      unawaited(_incomingMedia());
    }
    if (state != AppLifecycleState.resumed) {
      unawaited(widget.library.flush());
      unawaited(widget.settings.flush());
    }
  }

  @override
  void dispose() {
    _reconcileTimer?.cancel();
    mediaAccessChannel.setMethodCallHandler(null);
    WidgetsBinding.instance.removeObserver(this);
    if (Platform.isWindows) windowManager.removeListener(this);
    unawaited(widget.library.flush());
    unawaited(widget.settings.flush());
    _router.dispose();
    _online.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        onGenerateTitle: (c) => AppLocalizations.of(c)?.appName ?? 'Noor',
        routerConfig: _router,
        theme: lightTheme(),
        darkTheme: darkTheme(),
        themeMode: widget.settings.themeMode,
        locale: widget.settings.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }
}
