import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/media_item.dart';

/// A 16:9 frame captured by the player, or [fallback] until there is one.
class MediaThumbnail extends StatelessWidget {
  const MediaThumbnail({super.key, required this.item, required this.fallback});
  final MediaItem item;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final path = item.thumbnailPath;
    if (path == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 64,
        height: 36,
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          // Decode small: the captured frame is full video resolution.
          cacheWidth: 160,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}
