import 'package:flutter/material.dart';

import '../../app/format.dart';
import '../../app/l10n/gen/app_localizations.dart';
import '../../data/media_item.dart';

class MediaTile extends StatelessWidget {
  const MediaTile({
    super.key,
    required this.item,
    required this.onTap,
    this.missing = false,
    this.onToggleFavorite,
    this.onRemove,
  });

  final MediaItem item;

  /// From [LibraryController.isMissing]; checked off the build path.
  final bool missing;
  final VoidCallback onTap;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final exists = !missing;

    final meta = <String>[
      if (!exists) l.fileMissing,
      if (exists && item.durationMs > 0)
        formatDuration(Duration(milliseconds: item.durationMs)),
      if (exists && item.sizeBytes != null) formatSize(item.sizeBytes!),
    ].join('  •  ');

    return ListTile(
      enabled: exists,
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: Icon(
          exists
              ? (item.isAudio ? Icons.audiotrack : Icons.play_arrow_rounded)
              : Icons.error_outline,
        ),
      ),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (meta.isNotEmpty) Text(meta),
          if (exists && item.progress > 0 && !item.isFinished)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(value: item.progress),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onToggleFavorite != null)
            IconButton(
              tooltip: item.favorite ? l.removeFavorite : l.addFavorite,
              onPressed: onToggleFavorite,
              icon: Icon(
                item.favorite ? Icons.favorite : Icons.favorite_border,
              ),
            ),
          if (onRemove != null)
            IconButton(
              tooltip: l.removeFromLibrary,
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      onTap: exists ? onTap : null,
    );
  }
}
