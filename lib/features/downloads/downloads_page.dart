import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/player_route.dart';
import '../../data/library_controller.dart';
import '../../data/online_error.dart';
import '../../data/online_media_service.dart';
import '../../data/download_options.dart';
import '../../data/link_qualities.dart';
import '../../app/format.dart';

import '../../app/l10n/gen/app_localizations.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key, required this.library, required this.online});
  final LibraryController library;
  final OnlineMediaService online;
  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  final _url = TextEditingController();
  String? _validation;
  bool _audioOnly = false;
  int _height = 720;
  int _bitrate = 192;

  /// What the current link really offers, after "Show available qualities".
  LinkQualities? _qualities;
  String? _qualitiesFor;

  @override
  void initState() {
    super.initState();
    unawaited(widget.online.loadHistory().catchError((Object _) {}));
    _url.addListener(() {
      // Another link: its qualities are unknown again.
      if (_qualities != null && _url.text.trim() != _qualitiesFor) {
        setState(() => _qualities = _qualitiesFor = null);
      }
    });
  }

  Future<void> _probe() async {
    final l = AppLocalizations.of(context)!;
    final source = _url.text.trim();
    if (!isWebUrl(source)) {
      setState(() => _validation = l.invalidLink);
      return;
    }
    setState(() => _validation = null);
    FocusScope.of(context).unfocus();
    try {
      final qualities = await widget.online.probe(source);
      if (!mounted) return;
      setState(() {
        _qualities = qualities;
        _qualitiesFor = source;
        final caps = qualities.caps;
        if (caps.isNotEmpty && !caps.containsKey(_height)) {
          // Keep the user's cap where possible: the best one at or below it.
          final below = caps.keys.where((c) => c > 0 && c <= _height);
          _height = below.isEmpty ? 0 : below.reduce((a, b) => a > b ? a : b);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            qualities.caps.isEmpty ? l.noQualityList : l.qualitiesListed,
          ),
        ),
      );
    } catch (_) {
      /* Service exposes the error. */
    }
  }

  Future<void> _enqueue() async {
    final l = AppLocalizations.of(context)!;
    final source = _url.text.trim();
    if (!isWebUrl(source)) {
      setState(() => _validation = l.invalidLink);
      return;
    }
    setState(() => _validation = null);
    FocusScope.of(context).unfocus();
    try {
      await widget.online.enqueue(
        source,
        options: DownloadOptions(
          audioOnly: _audioOnly,
          maxHeight: _height,
          audioBitrate: _bitrate,
        ),
      );
      if (!mounted) return;
      _url.clear(); // ready for the next link
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.addedToQueue)));
    } catch (_) {
      /* Invalid options are prevented by the form. */
    }
  }

  String _optionsLabel(AppLocalizations l, DownloadOptions o) => o.audioOnly
      ? 'MP3 ${o.audioBitrate} kbps'
      : o.maxHeight == 0
      ? l.highestQuality
      : '${o.maxHeight}p';

  String _withSize(String label, int? bytes) =>
      bytes == null ? label : '$label · ≈ ${formatSize(bytes)}';

  List<int> get _heightChoices {
    final caps = _qualities?.caps;
    if (caps == null || caps.isEmpty) return DownloadOptions.heights;
    // Same order as the full list: highest first, then descending.
    return DownloadOptions.heights.where(caps.containsKey).toList();
  }

  Future<void> _start(bool streaming) async {
    final source = _url.text.trim();
    if (!isWebUrl(source)) {
      setState(() => _validation = AppLocalizations.of(context)!.invalidLink);
      return;
    }
    setState(() => _validation = null);
    FocusScope.of(context).unfocus();
    try {
      if (streaming) {
        final media = await widget.online.resolve(source);
        if (mounted) context.openPlayer(media);
      } else {
        final item = await widget.online.download(
          source,
          options: DownloadOptions(
            audioOnly: _audioOnly,
            maxHeight: _height,
            audioBitrate: _bitrate,
          ),
        );
        if (mounted) {
          final l = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.downloadSaved),
              action: SnackBarAction(
                label: l.play,
                onPressed: () => context.openPlayer(item.path),
              ),
            ),
          );
        }
      }
    } catch (_) {
      /* Service exposes the error and keeps both actions available. */
    }
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final online = widget.online;
    return ListenableBuilder(
      listenable: Listenable.merge([online, widget.library]),
      builder: (context, _) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                l.onlineVideo,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(l.onlineHint),
              const SizedBox(height: 20),
              TextField(
                controller: _url,
                enabled: !online.busy,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l.videoLink,
                  hintText: 'https://…',
                  errorText: _validation,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: l.pasteLink,
                    onPressed: online.busy
                        ? null
                        : () async {
                            final data = await Clipboard.getData(
                              Clipboard.kTextPlain,
                            );
                            if (mounted && data?.text != null) {
                              setState(() {
                                _url.text = data!.text!.trim();
                                _validation = null;
                              });
                            }
                          },
                    icon: const Icon(Icons.content_paste),
                  ),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: online.busy ? null : _probe,
                  icon: const Icon(Icons.tune),
                  label: Text(l.checkQualities),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<bool>(
                initialValue: _audioOnly,
                decoration: InputDecoration(
                  labelText: l.downloadKind,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: false, child: Text(l.videoWithAudio)),
                  DropdownMenuItem(value: true, child: Text(l.audioOnlyMp3)),
                ],
                onChanged: online.busy
                    ? null
                    : (value) => setState(() => _audioOnly = value!),
              ),
              const SizedBox(height: 16),
              if (_audioOnly)
                DropdownButtonFormField<int>(
                  key: const ValueKey('audio-quality'),
                  initialValue: _bitrate,
                  decoration: InputDecoration(
                    labelText: l.audioQuality,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final rate in DownloadOptions.bitrates)
                      DropdownMenuItem(
                        value: rate,
                        child: Text(
                          _withSize('$rate kbps', _qualities?.mp3Size(rate)),
                        ),
                      ),
                  ],
                  onChanged: online.busy
                      ? null
                      : (value) => setState(() => _bitrate = value!),
                )
              else
                // A new quality list replaces the field, so its initial value
                // is always one of the listed items.
                KeyedSubtree(
                  key: ValueKey(_qualities),
                  child: DropdownButtonFormField<int>(
                    key: const ValueKey('video-quality'),
                    initialValue: _height,
                    decoration: InputDecoration(
                      labelText: l.videoQuality,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final height in _heightChoices)
                        DropdownMenuItem(
                          value: height,
                          child: Text(
                            _withSize(
                              height == 0 ? l.highestQuality : '${height}p',
                              _qualities?.caps[height],
                            ),
                          ),
                        ),
                    ],
                    onChanged: online.busy
                        ? null
                        : (value) => setState(() => _height = value!),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                _audioOnly ? l.audioFormatHint : l.videoQualityHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  // While the single transfer slot is taken, Download queues.
                  if (online.busy ||
                      online.hasTransfer ||
                      online.engineUpdating ||
                      online.startingQueued)
                    FilledButton.icon(
                      onPressed: _enqueue,
                      icon: const Icon(Icons.playlist_add),
                      label: Text(l.addToQueue),
                    )
                  else
                    FilledButton.icon(
                      onPressed: () => _start(false),
                      icon: const Icon(Icons.download),
                      label: Text(
                        _audioOnly ? l.downloadAudio : l.downloadVideo,
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: online.busy ? null : () => _start(true),
                    icon: const Icon(Icons.play_circle_outline),
                    label: Text(l.streaming),
                  ),
                  if (online.canPause)
                    TextButton.icon(
                      onPressed: () => unawaited(online.pause()),
                      icon: const Icon(Icons.pause),
                      label: Text(l.pause),
                    ),
                  if (online.canResume)
                    TextButton.icon(
                      onPressed: () => unawaited(online.resume()),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(l.resumeDownload),
                    ),
                  if (online.busy || online.hasTransfer)
                    TextButton(
                      onPressed: () => unawaited(online.cancel()),
                      child: Text(l.cancelAction),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l.publicDownloadHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(l.onlineLimit, style: Theme.of(context).textTheme.bodySmall),
              // A paused or failed transfer is not busy but must stay visible.
              if (online.busy || online.hasTransfer) ...[
                const SizedBox(height: 20),
                Text(
                  online.stage == OnlineStage.paused ||
                          online.stage == OnlineStage.failed
                      ? l.downloadPaused
                      : online.stage == OnlineStage.waiting
                      ? l.downloadWaiting
                      : online.stage == OnlineStage.downloading
                      ? l.downloadingVideo
                      : l.preparingLink,
                ),
                const SizedBox(height: 8),
                // Only an active operation animates; a paused one holds still.
                LinearProgressIndicator(
                  value: online.busy ? online.progress : online.progress ?? 0,
                ),
                if (online.progress != null)
                  Text('${(online.progress! * 100).round()}%'),
              ],
              if (online.stage == OnlineStage.cancelled) ...[
                const SizedBox(height: 16),
                Text(l.operationCancelled),
              ],
              if (online.error != null) ...[
                const SizedBox(height: 20),
                ...() {
                  final kind = classifyOnlineError(online.error);
                  return [
                    Text(
                      onlineErrorText(l, kind),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    // Streaming cannot help when the source itself refuses.
                    if (_streamingMayHelp(kind)) ...[
                      const SizedBox(height: 8),
                      Text(l.tryStreaming),
                    ],
                  ];
                }(),
                ExpansionTile(
                  title: Text(l.errorDetails),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(online.error!),
                    ),
                  ],
                ),
              ],
              if (online.queue.isNotEmpty) ...[
                const SizedBox(height: 28),
                Text(
                  l.queueTitle(online.queue.length),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (online.canResume)
                  Text(
                    l.queueWaitingPaused,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                for (final item in online.queue)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule),
                    title: Text(
                      item.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                    ),
                    subtitle: Text(_optionsLabel(l, item.options)),
                    trailing: IconButton(
                      tooltip: l.removeFromQueue,
                      onPressed: () => online.removeFromQueue(item),
                      icon: const Icon(Icons.close),
                    ),
                  ),
              ],
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.completedDownloads,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: l.openDownloadsFolder,
                    icon: const Icon(Icons.folder_open),
                    onPressed: () async {
                      try {
                        await online.openDownloadsFolder();
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l.folderOpenHint)),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (online.downloads.isEmpty) Text(l.downloadsEmpty),
              for (final item in online.downloads)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    item.isAudio
                        ? Icons.audio_file_outlined
                        : Icons.video_file_outlined,
                  ),
                  title: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: item.savedLocation == null
                      ? null
                      : Text(
                          item.savedLocation!,
                          textDirection: TextDirection.ltr,
                        ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (Platform.isAndroid && !item.isContentUri)
                        IconButton(
                          tooltip: l.saveToPhoneDownloads,
                          onPressed: online.busy
                              ? null
                              : () async {
                                  try {
                                    await online.saveExistingToDownloads(item);
                                  } catch (_) {
                                    /* Error shown by service. */
                                  }
                                },
                          icon: const Icon(Icons.save_alt),
                        ),
                      // Missing files are pruned by reconcileDownloads and the
                      // player shows "file not found"; avoid sync disk I/O on
                      // every progress rebuild.
                      IconButton(
                        tooltip: l.play,
                        onPressed: () => context.openPlayer(item.path),
                        icon: const Icon(Icons.play_circle_fill),
                      ),
                    ],
                  ),
                  onTap: () => context.openPlayer(item.path),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String onlineErrorText(AppLocalizations l, OnlineErrorKind kind) =>
    switch (kind) {
      OnlineErrorKind.network => l.errorNetwork,
      OnlineErrorKind.private => l.errorPrivate,
      OnlineErrorKind.loginRequired => l.errorLoginRequired,
      OnlineErrorKind.unavailable => l.errorUnavailable,
      OnlineErrorKind.unsupported => l.errorUnsupported,
      OnlineErrorKind.quality => l.errorQuality,
      OnlineErrorKind.tooLarge => l.errorTooLarge,
      OnlineErrorKind.storage => l.errorStorage,
      OnlineErrorKind.engine => l.errorEngine,
      OnlineErrorKind.other => l.onlineUnavailable,
    };

bool _streamingMayHelp(OnlineErrorKind kind) => const {
  OnlineErrorKind.quality,
  OnlineErrorKind.tooLarge,
  OnlineErrorKind.storage,
  OnlineErrorKind.other,
}.contains(kind);
