import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'l10n/gen/app_localizations.dart';

/// Adaptive shell: bottom bar on narrow screens (Android phones),
/// side rail on wide screens (Windows / tablets).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  void _go(int i) =>
      shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final items = [
      (Icons.home_outlined, Icons.home, l.navHome),
      (Icons.video_library_outlined, Icons.video_library, l.navLibrary),
      (Icons.download_outlined, Icons.download, l.navDownloads),
      (Icons.settings_outlined, Icons.settings, l.navSettings),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 720;

    final appBar = shell.currentIndex == 0
        ? null
        : AppBar(
            leading: BackButton(onPressed: () => _go(0)),
            title: Text(items[shell.currentIndex].$3),
          );
    final Widget page;
    if (wide) {
      page = Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            NavigationRail(
              extended: MediaQuery.sizeOf(context).width >= 1000,
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _go,
              destinations: [
                for (final it in items)
                  NavigationRailDestination(
                    icon: Icon(it.$1),
                    selectedIcon: Icon(it.$2),
                    label: Text(it.$3),
                  ),
              ],
            ),
            Expanded(child: shell),
          ],
        ),
      );
    } else {
      page = Scaffold(
        appBar: appBar,
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _go,
          destinations: [
            for (final it in items)
              NavigationDestination(
                icon: Icon(it.$1),
                selectedIcon: Icon(it.$2),
                label: it.$3,
              ),
          ],
        ),
      );
    }
    return PopScope(
      canPop: shell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && shell.currentIndex != 0) _go(0);
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () => _go(0),
          const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () =>
              _go(0),
          const SingleActivator(LogicalKeyboardKey.browserBack): () => _go(0),
        },
        child: Focus(autofocus: true, child: page),
      ),
    );
  }
}
