import 'dart:ui';

import 'package:flutter/material.dart';

import '../utils/palette.dart';
import 'animated_tint.dart';

/// Immersive Now Playing backdrop (NOWPLAYING.md NP1): the current track's
/// artwork rendered full-bleed, heavily blurred and darkened, with a
/// vignette and a soft brand-tinted glow bleeding through. Artwork itself is
/// never recoloured — only this backdrop and downstream chrome pick up
/// [tintColor] (matches the Home hero / MiniPlayer adaptive-theming rule,
/// DECISIONLOG 2026-07-11).
///
/// The blurred-art layer cross-fades on [artUri] change over
/// [kTintTransition] (the same 400 ms contract the palette tint already
/// uses), so a track skip glides the backdrop instead of snapping.
class NowPlayingBackground extends StatelessWidget {
  const NowPlayingBackground({
    super.key,
    required this.artUri,
    required this.tintColor,
    required this.child,
  });

  final Uri? artUri;
  final Color? tintColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Uri? uri = artUri;
    final Color? tint = tintColor;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ColoredBox(color: cs.surface),
        AnimatedSwitcher(
          duration: kTintTransition,
          child: uri == null
              ? const SizedBox.shrink(
                  key: ValueKey<String>('now-playing-bg-none'),
                )
              : KeyedSubtree(
                  key: ValueKey<String>('now-playing-bg-${uri.toString()}'),
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                    child: Image.network(
                      uri.toString(),
                      fit: BoxFit.cover,
                      cacheWidth: 64,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
        ),
        // Scrim — keeps foreground content readable over any artwork.
        DecoratedBox(
          key: const Key('now-playing-bg-scrim'),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
          ),
        ),
        // Vignette — darkens the edges so the hero art (painted on top by
        // the caller) reads as the visual focus.
        const DecoratedBox(
          key: Key('now-playing-bg-vignette'),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1.1,
              colors: <Color>[Colors.transparent, Colors.black54],
              stops: <double>[0.55, 1.0],
            ),
          ),
        ),
        if (tint != null)
          AnimatedTint(
            tint: brandBlend(tint),
            builder: (BuildContext context, Color glow) => DecoratedBox(
              key: const Key('now-playing-bg-glow'),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.3),
                  radius: 1.0,
                  colors: <Color>[
                    glow.withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        child,
      ],
    );
  }
}
