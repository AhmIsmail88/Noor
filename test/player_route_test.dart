import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:noor/app/player_route.dart';

void main() {
  testWidgets('opening a second video replaces the open player', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        GoRoute(
          path: '/player',
          builder: (_, state) => Text('playing ${state.extra}'),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    openPlayerRoute(router, 'first.mp4');
    await tester.pumpAndSettle();
    expect(find.text('playing first.mp4'), findsOneWidget);

    // E.g. "Play" on the download-complete snackbar during playback.
    openPlayerRoute(router, 'second.mp4');
    await tester.pumpAndSettle();
    expect(find.text('playing second.mp4'), findsOneWidget);
    expect(find.text('playing first.mp4', skipOffstage: false), findsNothing);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(router.canPop(), isFalse);
    router.dispose();
  });
}
