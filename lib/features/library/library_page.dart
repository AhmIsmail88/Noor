import 'package:flutter/material.dart';

import '../../app/player_route.dart';
import '../../app/l10n/gen/app_localizations.dart';
import '../../data/library_controller.dart';
import '../../data/media_item.dart';
import '../../data/music_separation.dart';
import 'media_tile.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.library, this.separation});
  final LibraryController library;
  final MusicSeparationService? separation;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String _query = '';
  LibraryFilter _filter = LibraryFilter.all;

  /// Removal is immediate (only the library entry, never the file) and can
  /// be undone from the snackbar, so no confirmation dialog is needed.
  void _remove(MediaItem item) {
    final l = AppLocalizations.of(context)!;
    widget.library.remove(item.path);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l.removedFromLibrary(item.title)),
          persist: false, // otherwise it never hides (it has an action)
          action: SnackBarAction(
            label: l.undo,
            onPressed: () => widget.library.restore(item),
          ),
        ),
      );
  }

  /// Runs in the background (minutes); the card above the list shows it.
  Future<void> _separate(MediaItem item, SeparationMode mode) async {
    final service = widget.separation!;
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    if (service.current != null) {
      messenger.showSnackBar(SnackBar(content: Text(l.separationBusy)));
      return;
    }
    final suffix = mode == SeparationMode.removeMusic
        ? l.noMusicSuffix
        : l.musicOnlySuffix;
    try {
      final result = await service.separate(
        item,
        mode,
        title: '${item.title} ($suffix)',
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.separationDone(result.title)),
          persist: false,
          action: SnackBarAction(
            label: l.play,
            onPressed: () {
              if (mounted) context.openPlayer(result.path);
            },
          ),
        ),
      );
    } catch (e) {
      if (e is StateError && e.message == 'Cancelled') return;
      debugPrint('Separation: $e');
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is NoAudioError ? l.separationNoAudio : l.separationFailed,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final separation = widget.separation;
    return ListenableBuilder(
      listenable: Listenable.merge([widget.library, ?separation]),
      builder: (context, _) {
        if (widget.library.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.video_library_outlined, size: 64),
                const SizedBox(height: 12),
                Text(l.libraryEmpty),
              ],
            ),
          );
        }
        final items = widget.library.query(_query, _filter);
        final labels = {
          LibraryFilter.all: l.filterAll,
          LibraryFilter.favorites: l.filterFavorites,
          LibraryFilter.recent: l.filterRecent,
        };
        final job = separation?.current;
        return Column(
          children: [
            if (job != null) _SeparationCard(service: separation!, job: job),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l.searchHint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final f in LibraryFilter.values)
                      ChoiceChip(
                        label: Text(labels[f]!),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(child: Text(l.noResults))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final item = items[i];
                        return MediaTile(
                          item: item,
                          missing: widget.library.isMissing(item.path),
                          onTap: () => context.openPlayer(item.path),
                          onToggleFavorite: () =>
                              widget.library.toggleFavorite(item.path),
                          onRemove: () => _remove(item),
                          onSeparate: separation?.available == true
                              ? (mode) => _separate(item, mode)
                              : null,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// The running separation: file, stage, progress and Cancel.
class _SeparationCard extends StatelessWidget {
  const _SeparationCard({required this.service, required this.job});
  final MusicSeparationService service;
  final SeparationJob job;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final stage = switch (job.stage) {
      SeparationStage.preparing => l.separationPreparing,
      SeparationStage.separating => l.separationSeparating,
      SeparationStage.saving => l.separationSaving,
    };
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Icon(
              job.mode == SeparationMode.removeMusic
                  ? Icons.music_off_outlined
                  : Icons.music_note_outlined,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(stage, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: job.progress),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('${(job.progress * 100).round()}%'),
            IconButton(
              tooltip: MaterialLocalizations.of(context).cancelButtonLabel,
              onPressed: service.cancel,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}
