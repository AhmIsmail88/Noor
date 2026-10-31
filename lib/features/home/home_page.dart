import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/player_route.dart';
import '../../app/brand.dart';
import '../../app/l10n/gen/app_localizations.dart';
import '../../data/library_controller.dart';
import '../../data/media_access.dart';
import '../library/media_tile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.library});
  final LibraryController library;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _importing = false;

  Future<void> _open(
    BuildContext context, {
    bool audio = false,
    bool folder = false,
  }) async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final List<dynamic> entries;
      if (Platform.isAndroid) {
        entries =
            await mediaAccessChannel.invokeListMethod<dynamic>('pick', {
              'audio': audio,
            }) ??
            [];
      } else if (folder) {
        final directory = await FilePicker.getDirectoryPath();
        entries = directory == null ? [] : [directory];
      } else {
        final files = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: [...videoExtensions, ...audioExtensions],
        );
        entries = files.map((file) => file.path).whereType<String>().toList();
      }
      final items = await importMediaReferences(widget.library, entries);
      final firstPath = items.firstOrNull?.path;
      if (context.mounted && firstPath != null) {
        context.openPlayer(firstPath);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.importFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: widget.library,
      builder: (context, _) {
        final resume = widget.library.continueWatching;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 16),
                const Center(child: NoorMark(size: 120)),
                const SizedBox(height: 16),
                Text(
                  l.welcome,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                Center(
                  child: FilledButton.icon(
                    onPressed: _importing ? null : () => _open(context),
                    icon: const Icon(Icons.folder_open),
                    label: Text(_importing ? l.importingVideo : l.openVideo),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: _importing
                        ? null
                        : () => _open(
                            context,
                            audio: Platform.isAndroid,
                            folder: !Platform.isAndroid,
                          ),
                    icon: Icon(
                      Platform.isAndroid ? Icons.audio_file : Icons.folder_open,
                    ),
                    label: Text(
                      Platform.isAndroid ? l.openAudio : l.openFolder,
                    ),
                  ),
                ),
                if (!Platform.isAndroid)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(l.dropMediaHint, textAlign: TextAlign.center),
                  ),
                const SizedBox(height: 12),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/downloads'),
                    icon: const Icon(Icons.link),
                    label: Text(l.onlineVideo),
                  ),
                ),
                if (resume.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Text(
                    l.continueWatching,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final item in resume)
                    MediaTile(
                      item: item,
                      onTap: () => context.openPlayer(item.path),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
