import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path/path.dart' as p;

import '../../app/player_route.dart';
import '../../app/format.dart';
import '../../app/l10n/gen/app_localizations.dart';
import '../../app/theme.dart';
import '../../data/library_controller.dart';
import '../../data/media_item.dart';
import '../../data/online_media_service.dart';
import '../../data/video_folder.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.path,
    required this.library,
    this.onlineSource,
    this.online,
    this.autoplayNext = false,
  });
  final String path;
  final LibraryController library;
  final ResolvedMedia? onlineSource;
  final OnlineMediaService? online;

  /// When playback ends, count down and open the next video.
  final bool autoplayNext;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with WidgetsBindingObserver {
  static const _background = MethodChannel('noor/playback');

  /// Only one player may produce sound; the newest one takes over and owns
  /// the shared playback notification and its method-channel handler.
  static _PlayerPageState? _active;
  bool get _isActive => identical(_active, this);

  late final Player _player = _createPlayer();
  Player _createPlayer() {
    MediaKit.ensureInitialized();
    return Player(
      configuration: PlayerConfiguration(
        logLevel: kDebugMode ? MPVLogLevel.debug : MPVLogLevel.error,
      ),
    );
  }

  late final VideoController _video = VideoController(_player);
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _hideTimer;
  Timer? _saveTimer;
  Timer? _decoderErrorTimer;

  String? _error;
  bool _notFound = false;
  bool _fullscreen = false;
  bool _controlsVisible = true;
  double? _dragMs;
  double _rate = 1.0;
  double _volume = 100;
  bool _muted = false;
  bool _opening = false;
  bool _ready = false;
  bool _disposed = false;
  bool _backgroundDismissed = false;
  bool _startedOnce = false;
  String? _nextPath;
  static const _upNextDelay = 5;
  Timer? _upNextTimer;
  int? _upNextSeconds;
  double? _edgeStart;
  double _edgeDistance = 0;

  bool get _desktop => !kIsWeb && Platform.isWindows;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _active?._yieldPlayback();
    _active = this;
    widget.library.capturePlaybackProgress = _saveProgress;
    _subs.addAll([
      if (kDebugMode)
        _player.stream.log.listen((log) {
          if (log.prefix.contains('vd') || log.prefix.contains('ffmpeg')) {
            debugPrint(
              'NOOR decoder ${log.prefix} ${log.level}: ${log.text.trim()}',
            );
          }
        }),
      _player.stream.error.listen(_onPlaybackError),
      _player.stream.tracks.listen((_) {
        if (mounted) setState(() {});
      }),
      _player.stream.track.listen((_) {
        if (mounted) setState(() {});
      }),
      _player.stream.playing.listen(_onPlaying),
      _player.stream.completed.listen((done) {
        if (!done) return;
        _saveProgress(finished: true);
        _startUpNext();
      }),
    ]);
    if (Platform.isAndroid) {
      _background.setMethodCallHandler((call) async {
        if (_disposed) return;
        switch (call.method) {
          case 'play':
            await _player.play();
          case 'pause':
            await _player.pause();
          case 'stop':
            _backgroundDismissed = true;
            await _player.pause();
            await _background.invokeMethod<void>('stop');
          case 'seek':
            await _player.seek(Duration(milliseconds: call.arguments as int));
        }
      });
    }
    _start();
    _loadNext();
  }

  Future<void> _loadNext() async {
    if (widget.onlineSource != null) return;
    final current = widget.library.findByPath(widget.path);
    final group = current?.playbackGroup;
    if (current?.isContentUri == true && group == null) return;
    final paths = group == null
        ? await folderVideos(widget.path)
        : (widget.library
              .query('', LibraryFilter.all)
              .where((item) => item.playbackGroup == group)
              .map((item) => item.path)
              .toList()
            ..sort(
              (a, b) => (widget.library.findByPath(a)?.title ?? a)
                  .toLowerCase()
                  .compareTo(
                    (widget.library.findByPath(b)?.title ?? b).toLowerCase(),
                  ),
            ));
    final index = paths.indexWhere((path) => p.equals(path, widget.path));
    for (var i = index + 1; index >= 0 && i < paths.length; i++) {
      final exists = paths[i].startsWith('content:')
          ? await const MethodChannel('noor/online_media')
                    .invokeMethod<bool>('canRead', {'uri': paths[i]}) ==
                true
          : await File(paths[i]).exists();
      if (exists) {
        if (mounted) setState(() => _nextPath = paths[i]);
        return;
      }
    }
  }

  void _onPlaybackError(String message) {
    if (_disposed) return;
    _decoderErrorTimer?.cancel();
    // mpv reports the failed hardware probe through its error stream before
    // successfully falling back to software. Keep the video surface attached
    // during that transition; still surface a decoder failure if it stalls.
    if (message.toLowerCase().contains('could not open codec')) {
      final position = _player.state.position;
      _decoderErrorTimer = Timer(const Duration(seconds: 2), () {
        if (_disposed) return;
        final recovered =
            _player.state.playing &&
            _player.state.position >
                position + const Duration(milliseconds: 250);
        if (!recovered && mounted) setState(() => _error = message);
      });
    } else if (mounted) {
      setState(() => _error = message);
    }
  }

  void _back() {
    if (_fullscreen) {
      _toggleFullscreen();
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _startUpNext() {
    if (!widget.autoplayNext || _nextPath == null || !_isActive || _disposed) {
      return;
    }
    _upNextTimer?.cancel();
    setState(() => _upNextSeconds = _upNextDelay);
    _upNextTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed) return timer.cancel();
      final left = (_upNextSeconds ?? 1) - 1;
      if (left > 0) return setState(() => _upNextSeconds = left);
      _cancelUpNext();
      unawaited(_next());
    });
  }

  void _cancelUpNext() {
    _upNextTimer?.cancel();
    _upNextTimer = null;
    if (_upNextSeconds != null && !_disposed) {
      setState(() => _upNextSeconds = null);
    }
  }

  Future<void> _next() async {
    final path = _nextPath;
    if (path == null) return;
    _cancelUpNext();
    _saveProgress();
    await widget.library.flush();
    if (!mounted) return;
    widget.library.importPath(path, isAudio: isAudioFile(path));
    context.openPlayer(path);
  }

  Future<void> _start() async {
    if (_opening || _disposed) return;
    _decoderErrorTimer?.cancel();
    setState(() {
      _opening = true;
      _ready = false;
      _notFound = false;
      _error = null;
    });
    final item = widget.library.findByPath(widget.path);
    // A streaming retry has no library entry. Preserve the current position
    // before refreshing an expired source URL or reopening the player.
    final resumeMs = _startedOnce && _player.state.position > Duration.zero
        ? _player.state.position.inMilliseconds
        : (item != null && !item.isFinished)
        ? item.positionMs
        : 0;
    try {
      var source = widget.onlineSource;
      if (_startedOnce && source != null && widget.online != null) {
        source = await widget.online!.resolve(source.sourceUrl);
        if (_disposed) return;
      }
      _startedOnce = true;
      final exists =
          source != null ||
          (item?.isContentUri == true
              ? await const MethodChannel('noor/online_media')
                        .invokeMethod<bool>('canRead', {'uri': widget.path}) ==
                    true
              : await File(widget.path).exists());
      if (_disposed) return;
      if (!exists) {
        setState(() => _notFound = true);
        return;
      }
      if (Platform.isAndroid) {
        // Samsung MediaCodec rejects MPEG-4 Part 2, then mpv falls back to
        // software. Avoid surfacing the failed probe as a fatal player error.
        // Keep GPU rendering and hardware decoding for modern codecs.
        await _video.platform.future;
        if (_disposed) return;
        await (_player.platform as NativePlayer).setProperty(
          'hwdec-codecs',
          'h264,hevc,mpeg2video,vp8,vp9,av1',
        );
        if (_disposed) return;
      }
      // Do not start playback (or save position zero) until resume is applied.
      await _player.open(
        Media(source?.url ?? widget.path, httpHeaders: source?.headers),
        play: false,
      );
      if (_disposed) return;
      if (resumeMs > 0) await _resume(resumeMs);
      if (_disposed) return;
      _ready = true;
      // A newer player took over while this one was still opening.
      if (!_isActive) return;
      await _player.play();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (!_disposed) setState(() => _opening = false);
    }
  }

  Future<void> _resume(int ms) async {
    if (_player.state.duration <= Duration.zero) {
      try {
        await _player.stream.duration
            .firstWhere((d) => d > Duration.zero)
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        throw StateError(
          'Unable to determine duration for resume. Retry playback.',
        );
      }
    }
    if (_disposed) return;
    final target = ms.clamp(0, _player.state.duration.inMilliseconds);
    await _player.seek(Duration(milliseconds: target));
    if (!mounted) return;
    final l = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.resumedAt(formatDuration(Duration(milliseconds: ms)))),
      ),
    );
  }

  /// Called when a newer player opens: keep the position, stop the sound.
  void _yieldPlayback() {
    if (_disposed) return;
    // Runs inside the new page's initState (a build); notify afterwards.
    _saveProgress(inDispose: true);
    Future.microtask(widget.library.refresh);
    unawaited(widget.library.flush());
    unawaited(_player.pause());
  }

  Future<void> _syncBackground() async {
    if (!Platform.isAndroid ||
        _disposed ||
        !_ready ||
        _backgroundDismissed ||
        !_isActive) {
      return;
    }
    try {
      await _background.invokeMethod<void>('update', {
        'title':
            widget.onlineSource?.title ??
            widget.library.findByPath(widget.path)?.title ??
            'NOOR',
        'playing': _player.state.playing,
        'position': _player.state.position.inMilliseconds,
        'duration': _player.state.duration.inMilliseconds,
      });
    } on PlatformException catch (e) {
      debugPrint('NOOR playback service: $e');
    }
  }

  void _onPlaying(bool playing) {
    if (_disposed || !_ready) return;
    // Replaying or seeking back after the end means "stay on this video".
    if (playing) _cancelUpNext();
    if (playing) _backgroundDismissed = false;
    unawaited(_syncBackground());
    _saveTimer?.cancel();
    if (playing) {
      _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _saveProgress();
        unawaited(_maybeCaptureThumbnail());
      });
      _scheduleHide();
    } else {
      _saveProgress();
      unawaited(widget.library.flush());
      _hideTimer?.cancel();
      if (mounted) setState(() => _controlsVisible = true);
    }
  }

  bool _thumbnailTried = false;

  /// One frame per video, taken past the intro (10%, at most 30 s in), for
  /// the library and downloads lists. Audio and streams are skipped.
  Future<void> _maybeCaptureThumbnail() async {
    if (_thumbnailTried || widget.onlineSource != null || _disposed) return;
    final item = widget.library.findByPath(widget.path);
    if (item == null || item.isAudio || item.thumbnailPath != null) {
      _thumbnailTried = true;
      return;
    }
    final duration = _player.state.duration;
    if (duration <= Duration.zero || (_player.state.width ?? 0) <= 0) return;
    var due = duration * 0.1;
    if (due > const Duration(seconds: 30)) due = const Duration(seconds: 30);
    if (_player.state.position < due) return;
    _thumbnailTried = true;
    try {
      final jpeg = await _player.screenshot(format: 'image/jpeg');
      // Some decoders return nothing or a blank frame; leave the icon then.
      if (jpeg != null && jpeg.length > 2048) {
        await widget.library.saveThumbnail(widget.path, jpeg);
      }
    } catch (e) {
      debugPrint('NOOR thumbnail: $e');
    }
  }

  void _saveProgress({bool finished = false, bool inDispose = false}) {
    if (!_ready || widget.onlineSource != null) return;
    final dur = _player.state.duration.inMilliseconds;
    if (dur <= 0) return;
    final pos = finished ? dur : _player.state.position.inMilliseconds;
    widget.library.saveProgress(
      widget.path,
      positionMs: pos,
      durationMs: dur,
      notify: !inDispose,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !_disposed) {
      _saveProgress();
      unawaited(widget.library.flush());
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _player.state.playing) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _showControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    if (_player.state.playing) _scheduleHide();
  }

  void _onTap() {
    if (_desktop) {
      _player.playOrPause();
      _showControls();
    } else {
      setState(() => _controlsVisible = !_controlsVisible);
      if (_controlsVisible) _scheduleHide();
    }
  }

  void _seekBy(Duration d) {
    final target = _player.state.position + d;
    final max = _player.state.duration;
    // Live streams and still-probing sources report a zero duration; clamping
    // to it would jump back to the start on every forward seek.
    _player.seek(
      target < Duration.zero
          ? Duration.zero
          : (max > Duration.zero && target > max ? max : target),
    );
    _showControls();
  }

  void _applyVolume() => _player.setVolume(_muted ? 0 : _volume);

  void _nudgeVolume(double delta) {
    setState(() {
      _volume = (_volume + delta).clamp(0, 100);
      _muted = false;
    });
    _applyVolume();
    _showControls();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _applyVolume();
  }

  Future<void> _toggleFullscreen() async {
    final next = !_fullscreen;
    setState(() => _fullscreen = next);
    if (_desktop) {
      await windowManager.setFullScreen(next);
    } else {
      await SystemChrome.setEnabledSystemUIMode(
        next ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
      if (_disposed) return;
      await SystemChrome.setPreferredOrientations(
        next
            ? [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
            : DeviceOrientation.values,
      );
    }
  }

  void _restoreSystemUi() {
    if (!_fullscreen) return;
    if (_desktop) {
      windowManager.setFullScreen(false);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.library.capturePlaybackProgress == _saveProgress) {
      widget.library.capturePlaybackProgress = null;
    }
    _disposed = true;
    _hideTimer?.cancel();
    _saveTimer?.cancel();
    _upNextTimer?.cancel();
    _saveProgress(inDispose: true);
    _decoderErrorTimer?.cancel();
    unawaited(widget.library.flush());
    final library = widget.library;
    Future.microtask(library.refresh);
    for (final s in _subs) {
      s.cancel();
    }
    _restoreSystemUi();
    // A replaced player is disposed after its successor started; it must not
    // remove the successor's lock-screen handler or stop its notification.
    if (_isActive) {
      _active = null;
      if (Platform.isAndroid) {
        _background.setMethodCallHandler(null);
        unawaited(_background.invokeMethod<void>('stop'));
      }
    }
    _player.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Theme(
      data: darkTheme(),
      child: PopScope(
        canPop: !_fullscreen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _toggleFullscreen();
        },
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.space):
                _player.playOrPause,
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                _seekBy(const Duration(seconds: -5)),
            const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                _seekBy(const Duration(seconds: 5)),
            const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                _nudgeVolume(5),
            const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                _nudgeVolume(-5),
            const SingleActivator(LogicalKeyboardKey.keyM): _toggleMute,
            const SingleActivator(LogicalKeyboardKey.keyF): _toggleFullscreen,
            const SingleActivator(LogicalKeyboardKey.escape): _back,
            const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true):
                _back,
            const SingleActivator(LogicalKeyboardKey.browserBack): _back,
            const SingleActivator(LogicalKeyboardKey.keyN): () => _next(),
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(backgroundColor: Colors.black, body: _body(l)),
          ),
        ),
      ),
    );
  }

  Widget _body(AppLocalizations l) {
    if (_notFound) return _errorView(l, l.fileNotFound, canRetry: false);
    return MouseRegion(
      onHover: (_) => _showControls(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        onHorizontalDragStart: (details) {
          final width = MediaQuery.sizeOf(context).width;
          final x = details.localPosition.dx;
          _edgeStart = x < 28 || x > width - 28 ? x : null;
          _edgeDistance = 0;
        },
        onHorizontalDragUpdate: (details) =>
            _edgeDistance += details.primaryDelta ?? 0,
        onHorizontalDragEnd: (_) {
          final start = _edgeStart;
          _edgeStart = null;
          if (start != null &&
              (start < 28 ? _edgeDistance > 72 : _edgeDistance < -72)) {
            _back();
          }
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: Video(
                controller: _video,
                controls: NoVideoControls,
                pauseUponEnteringBackgroundMode: false,
              ),
            ),
            if (widget.library.findByPath(widget.path)?.isAudio == true)
              const Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Icon(
                      Icons.audiotrack,
                      size: 96,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: StreamBuilder<bool>(
                  stream: _player.stream.buffering,
                  initialData: _player.state.buffering,
                  builder: (context, snapshot) =>
                      _opening || (snapshot.data ?? false)
                      ? const Center(child: CircularProgressIndicator())
                      : const SizedBox.shrink(),
                ),
              ),
            ),
            Positioned.fill(child: _overlay(l)),
            if (_upNextSeconds != null && _nextPath != null)
              PositionedDirectional(
                end: 16,
                bottom: 140,
                child: SafeArea(child: _upNextCard(l)),
              ),
            // Keep Video mounted: mpv can emit recoverable errors while audio
            // and video continue. Replacing this subtree detached the picture.
            if (_error != null)
              PositionedDirectional(
                top: 64,
                start: 16,
                end: 16,
                child: SafeArea(
                  child: Material(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.playerError(_error!),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: _opening ? null : _start,
                                child: Text(l.retry),
                              ),
                              IconButton(
                                tooltip: MaterialLocalizations.of(context)
                                    .closeButtonTooltip,
                                onPressed: () => setState(() => _error = null),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (!_controlsVisible)
              PositionedDirectional(
                top: 0,
                start: 0,
                child: SafeArea(
                  child: IconButton.filledTonal(
                    tooltip: l.back,
                    onPressed: _back,
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _upNextCard(AppLocalizations l) {
    final next = _nextPath!;
    final title = widget.library.findByPath(next)?.title ?? titleFromPath(next);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Material(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.upNextIn(_upNextSeconds!, title),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: _cancelUpNext,
                    child: Text(
                      MaterialLocalizations.of(context).cancelButtonLabel,
                    ),
                  ),
                  FilledButton.tonal(onPressed: _next, child: Text(l.playNow)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorView(
    AppLocalizations l,
    String message, {
    required bool canRetry,
  }) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                children: [
                  if (canRetry)
                    FilledButton(
                      onPressed: () {
                        setState(() => _error = null);
                        _start();
                      },
                      child: Text(l.retry),
                    ),
                  OutlinedButton(onPressed: _back, child: Text(l.back)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scrim(Alignment from, Alignment to, Widget child) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: from,
        end: to,
        colors: const [Colors.black87, Colors.transparent],
      ),
    ),
    child: child,
  );

  Widget _overlay(AppLocalizations l) {
    final title =
        widget.onlineSource?.title ??
        widget.library.findByPath(widget.path)?.title ??
        widget.path.split(RegExp(r'[\\/]')).last;
    return AnimatedOpacity(
      opacity: _controlsVisible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !_controlsVisible,
        child: Column(
          children: [
            _scrim(
              Alignment.topCenter,
              Alignment.bottomCenter,
              SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: l.back,
                      onPressed: _back,
                      icon: const Icon(Icons.arrow_back),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _speedMenu(l),
                    ?_audioMenu(l),
                    _subtitleMenu(l),
                    IconButton(
                      tooltip: _fullscreen ? l.exitFullscreen : l.fullscreen,
                      onPressed: _toggleFullscreen,
                      icon: Icon(
                        _fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            _scrim(
              Alignment.bottomCenter,
              Alignment.topCenter,
              // Seek bar and transport always read left-to-right, also in RTL.
              Directionality(
                textDirection: TextDirection.ltr,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [_seekBar(), _transport(l)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seekBar() {
    return StreamBuilder<Duration>(
      stream: _player.stream.duration,
      initialData: _player.state.duration,
      builder: (context, durSnap) {
        final total = (durSnap.data ?? Duration.zero).inMilliseconds;
        return StreamBuilder<Duration>(
          stream: _player.stream.position,
          initialData: _player.state.position,
          builder: (context, posSnap) {
            final pos = (posSnap.data ?? Duration.zero).inMilliseconds;
            final max = total > 0 ? total.toDouble() : 1.0;
            final value = (_dragMs ?? pos.toDouble()).clamp(0.0, max);
            return Row(
              children: [
                Text(formatDuration(Duration(milliseconds: value.round()))),
                Expanded(
                  child: Slider(
                    value: value,
                    max: max,
                    onChanged: total > 0
                        ? (v) => setState(() => _dragMs = v)
                        : null,
                    onChangeEnd: (v) {
                      _player.seek(Duration(milliseconds: v.round()));
                      setState(() => _dragMs = null);
                    },
                  ),
                ),
                Text(formatDuration(Duration(milliseconds: total))),
              ],
            );
          },
        );
      },
    );
  }

  Widget _transport(AppLocalizations l) {
    final center = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l.seekBack,
          iconSize: 32,
          onPressed: () => _seekBy(const Duration(seconds: -10)),
          icon: const Icon(Icons.replay_10),
        ),
        StreamBuilder<bool>(
          stream: _player.stream.playing,
          initialData: _player.state.playing,
          builder: (context, snap) {
            final playing = snap.data ?? false;
            return IconButton(
              tooltip: playing ? l.pause : l.play,
              iconSize: 52,
              onPressed: _player.playOrPause,
              icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
            );
          },
        ),
        IconButton(
          tooltip: l.seekForward,
          iconSize: 32,
          onPressed: () => _seekBy(const Duration(seconds: 10)),
          icon: const Icon(Icons.forward_10),
        ),
        IconButton(
          tooltip: l.nextVideo,
          onPressed: _nextPath == null ? null : _next,
          iconSize: 32,
          icon: const Icon(Icons.skip_next),
        ),
      ],
    );

    if (!_desktop) return center; // phones use hardware volume keys

    final silent = _muted || _volume == 0;
    final volume = SizedBox(
      width: 200,
      child: Row(
        children: [
          IconButton(
            tooltip: silent ? l.unmute : l.mute,
            onPressed: _toggleMute,
            icon: Icon(silent ? Icons.volume_off : Icons.volume_up),
          ),
          Expanded(
            child: Slider(
              semanticFormatterCallback: (v) => '${v.round()}%',
              value: _muted ? 0 : _volume,
              max: 100,
              onChanged: (v) {
                setState(() {
                  _volume = v;
                  _muted = false;
                });
                _applyVolume();
              },
            ),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [center, volume],
          );
        }
        return Row(
          children: [
            volume,
            Expanded(child: Center(child: center)),
            const SizedBox(width: 200),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------ menus

  Widget _speedMenu(AppLocalizations l) => PopupMenuButton<double>(
    tooltip: l.speed,
    icon: const Icon(Icons.speed),
    onSelected: (v) {
      setState(() => _rate = v);
      _player.setRate(v);
    },
    itemBuilder: (_) => [
      for (final v in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
        CheckedPopupMenuItem<double>(
          value: v,
          checked: v == _rate,
          child: Text('${v == v.roundToDouble() ? v.toInt() : v}x'),
        ),
    ],
  );

  String _trackName(
    AppLocalizations l,
    int index,
    String? title,
    String? lang,
  ) {
    final parts = [
      if (title != null && title.isNotEmpty) title,
      if (lang != null && lang.isNotEmpty) lang,
    ];
    return parts.isEmpty ? l.trackN(index + 1) : parts.join(' · ');
  }

  Widget? _audioMenu(AppLocalizations l) {
    final tracks = _player.state.tracks.audio
        .where((t) => t.id != 'auto' && t.id != 'no')
        .toList();
    if (tracks.length < 2) return null;
    final current = _player.state.track.audio.id;
    return PopupMenuButton<AudioTrack>(
      tooltip: l.audioTrack,
      icon: const Icon(Icons.audiotrack),
      onSelected: _player.setAudioTrack,
      itemBuilder: (_) => [
        for (var i = 0; i < tracks.length; i++)
          CheckedPopupMenuItem<AudioTrack>(
            value: tracks[i],
            checked: tracks[i].id == current,
            child: Text(_trackName(l, i, tracks[i].title, tracks[i].language)),
          ),
      ],
    );
  }

  /// Menu sentinel: never a real mpv track id.
  static final _loadSubtitle = SubtitleTrack('noor-load-subtitle', null, null);
  SubtitleTrack? _externalSubtitle;

  Future<void> _pickSubtitle() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['srt', 'vtt', 'ass', 'ssa'],
      );
      final path = files.firstOrNull?.path;
      if (path == null || _disposed) return;
      final track = SubtitleTrack.uri(path, title: p.basename(path));
      await _player.setSubtitleTrack(track);
      if (mounted) setState(() => _externalSubtitle = track);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// Always shown: an external SRT/VTT can be added to any video.
  Widget _subtitleMenu(AppLocalizations l) {
    final tracks = _player.state.tracks.subtitle
        .where((t) => t.id != 'auto' && t.id != 'no')
        .toList();
    final current = _player.state.track.subtitle.id;
    final external = _externalSubtitle;
    return PopupMenuButton<SubtitleTrack>(
      tooltip: l.subtitles,
      icon: const Icon(Icons.subtitles),
      onSelected: (track) => identical(track, _loadSubtitle)
          ? unawaited(_pickSubtitle())
          : _player.setSubtitleTrack(track),
      itemBuilder: (_) => [
        CheckedPopupMenuItem<SubtitleTrack>(
          value: SubtitleTrack.no(),
          checked: current == 'no',
          child: Text(l.subtitlesOff),
        ),
        for (var i = 0; i < tracks.length; i++)
          CheckedPopupMenuItem<SubtitleTrack>(
            value: tracks[i],
            checked: tracks[i].id == current,
            child: Text(_trackName(l, i, tracks[i].title, tracks[i].language)),
          ),
        if (external != null && !tracks.any((t) => t.id == external.id))
          CheckedPopupMenuItem<SubtitleTrack>(
            value: external,
            checked: current == external.id,
            child: Text(external.title ?? l.subtitles),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<SubtitleTrack>(
          value: _loadSubtitle,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.file_open_outlined),
            title: Text(l.loadSubtitleFile),
          ),
        ),
      ],
    );
  }
}
