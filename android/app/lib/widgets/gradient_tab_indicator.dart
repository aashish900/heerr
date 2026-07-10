import 'package:flutter/material.dart';

import '../theme.dart';

/// Tab indicator: a thick rounded magenta->violet gradient bar under the
/// selected label. The thin line extending across the full tab bar comes
/// from TabBarThemeData's divider, not this painter, since a Decoration only
/// knows the label's own rect.
class GradientTabIndicator extends Decoration {
  const GradientTabIndicator({
    this.gradient = heerrGradient,
    this.thickness = 3,
  });

  final Gradient gradient;
  final double thickness;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _GradientTabIndicatorPainter(this, onChanged);
}

class _GradientTabIndicatorPainter extends BoxPainter {
  _GradientTabIndicatorPainter(this.decoration, VoidCallback? onChanged)
      : super(onChanged);

  final GradientTabIndicator decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final Size? size = configuration.size;
    if (size == null) return;
    final Rect bar = Rect.fromLTWH(
      offset.dx,
      offset.dy + size.height - decoration.thickness,
      size.width,
      decoration.thickness,
    );
    final Paint paint = Paint()..shader = decoration.gradient.createShader(bar);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bar, Radius.circular(decoration.thickness / 2)),
      paint,
    );
  }
}
