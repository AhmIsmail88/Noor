import 'package:flutter/material.dart';

import '../../app/player_route.dart';
import '../../app/l10n/gen/app_localizations.dart';
import '../../data/library_controller.dart';
import '../../data/media_item.dart';
import 'media_tile.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.library});
  final LibraryController library;

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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: widget.library,
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
        return Column(
          children: [
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
