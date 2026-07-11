import 'package:flutter/material.dart';

import '../utils/palette.dart';

/// Cross-fades [tint] changes over [kTintTransition] so a track skip glides
/// the accent colour to the next cover's tint instead of snapping (Part B —
/// HOMESCREEN.md §7). Shared by the Continue Listening card + MiniPlayer.
class AnimatedTint extends StatelessWidget {
  const AnimatedTint({super.key, required this.tint, required this.builder});

  final Color tint;
  final Widget Function(BuildContext context, Color tint) builder;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: tint),
      duration: kTintTransition,
      builder: (BuildContext context, Color? animated, _) =>
          builder(context, animated ?? tint),
    );
  }
}
