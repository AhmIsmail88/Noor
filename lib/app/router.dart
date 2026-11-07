import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../data/library_controller.dart';
import '../data/music_separation.dart';
import '../data/online_media_service.dart';
import '../features/downloads/downloads_page.dart';
import '../features/home/home_page.dart';
import '../features/library/library_page.dart';
import '../features/player/player_page.dart';
import '../features/settings/settings_page.dart';
import 'settings.dart';
import 'shell.dart';

GoRouter buildRouter(
  AppSettings settings,
  LibraryController library,
  OnlineMediaService online,
  MusicSeparationService separation,
) => GoRouter(
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (c, s) => HomePage(library: library),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/library',
              builder: (c, s) =>
                  LibraryPage(library: library, separation: separation),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/downloads',
              builder: (c, s) =>
                  DownloadsPage(library: library, online: online),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (c, s) =>
                  SettingsPage(settings: settings, online: online),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/player',
      builder: (c, s) {
        final source = s.extra;
        return source is ResolvedMedia
            ? PlayerPage(
                path: source.url,
                library: library,
                onlineSource: source,
                online: online,
              )
            : PlayerPage(
                key: ValueKey(source),
                path: source as String,
                library: library,
                autoplayNext: settings.autoplayNext,
                separation: separation,
              );
      },
    ),
  ],
);
