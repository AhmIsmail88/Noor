import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Opens the player, replacing one that is already showing so two players
/// never run at once (e.g. "Play" on a download-complete snackbar while
/// another video is playing, or "Open with NOOR" during playback).
void openPlayerRoute(GoRouter router, Object source) {
  if (router.state.matchedLocation == '/player') {
    router.pushReplacement('/player', extra: source);
  } else {
    router.push('/player', extra: source);
  }
}

extension OpenPlayer on BuildContext {
  void openPlayer(Object source) => openPlayerRoute(GoRouter.of(this), source);
}
