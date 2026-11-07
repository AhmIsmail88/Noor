import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/l10n/gen/app_localizations.dart';
import '../../app/player_route.dart';
import '../../data/media_item.dart';
import '../../data/music_separation.dart';

/// Starts a separation in the background and reports the result with a
/// snackbar on the app-wide messenger, so it shows wherever the user is
/// when it ends (minutes later). Used by the Library and the player.
Future<void> startSeparation(
  BuildContext context,
  MusicSeparationService service,
  MediaItem item,
  SeparationMode mode, {
  bool announceStart = false,
}) async {
  final l = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  // The app's router outlives the page that started the job.
  final router = GoRouter.of(context);
  if (service.current != null) {
    messenger.showSnackBar(SnackBar(content: Text(l.separationBusy)));
    return;
  }
  final suffix = mode == SeparationMode.removeMusic
      ? l.noMusicSuffix
      : l.musicOnlySuffix;
  final running = service.separate(
    item,
    mode,
    title: '${item.title} ($suffix)',
  );
  if (announceStart) {
    messenger.showSnackBar(SnackBar(content: Text(l.separationStarted)));
  }
  try {
    final result = await running;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l.separationDone(result.title)),
        persist: false,
        action: SnackBarAction(
          label: l.play,
          onPressed: () {
            openPlayerRoute(router, result.path);
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

/// The player's "music" button: the two modes, or progress while running.
class SeparationButton extends StatelessWidget {
  const SeparationButton({
    super.key,
    required this.service,
    required this.item,
  });
  final MusicSeparationService service;
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final job = service.current;
        if (job != null) {
          // Progress of whichever file is being separated; tap to cancel.
          return IconButton(
            tooltip:
                '${job.item.title} — ${(job.progress * 100).round()}% '
                '(${MaterialLocalizations.of(context).cancelButtonLabel})',
            onPressed: service.cancel,
            icon: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.square(
                  dimension: 26,
                  child: CircularProgressIndicator(
                    value: job.progress,
                    strokeWidth: 2.5,
                  ),
                ),
                Text(
                  '${(job.progress * 100).round()}',
                  style: const TextStyle(fontSize: 9),
                ),
              ],
            ),
          );
        }
        return PopupMenuButton<SeparationMode>(
          tooltip: l.musicSeparation,
          icon: const Icon(Icons.graphic_eq),
          onSelected: (mode) => startSeparation(
            context,
            service,
            item,
            mode,
            announceStart: true,
          ),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: SeparationMode.removeMusic,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.music_off_outlined),
                title: Text(l.removeMusic),
              ),
            ),
            PopupMenuItem(
              value: SeparationMode.musicOnly,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.music_note_outlined),
                title: Text(l.musicOnly),
              ),
            ),
          ],
        );
      },
    );
  }
}
