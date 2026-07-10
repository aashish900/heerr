import 'package:flutter/material.dart';

import '../theme.dart';

/// Paints [child] with the heerr magenta→purple→violet [heerrGradient] via a
/// [ShaderMask]. The child is rendered in white first (the shader replaces the
/// opaque pixels), so any glyph — an [Icon], an `SvgPicture`, etc. — comes out
/// gradient-tinted regardless of its own colour.
///
/// Used on the app's "hero" accents: the selected bottom-nav icon and the
/// Now Playing transport controls. Everything else stays solid magenta via the
/// theme's [ColorScheme.primary].
class GradientIcon extends StatelessWidget {
  const GradientIcon({
    super.key,
    required this.child,
    this.gradient = heerrGradient,
  });

  final Widget child;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (Rect bounds) => gradient.createShader(bounds),
      child: child,
    );
  }
}
