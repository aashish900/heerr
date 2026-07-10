import 'package:flutter/material.dart';

import '../theme.dart';

/// Tab indicator: a thick rounded magenta->violet gradient bar under the
/// selected label, with a thin faint magenta line extending past each end
/// and fading out — matches the reference screenshot's bold-bar-plus-glow
/// look. TabBar doesn't clip indicator painting to the tab's own segment, so
/// the fade is free to bleed into neighbouring tabs, which is the point.
class GradientTabIndicator extends Decoration {
  const GradientTabIndicator({
    this.gradient = heerrGradient,
    this.thickness = 3,
    this.fadeExtension = 20,
  });

  final Gradient gradient;
  final double thickness;
  final double fadeExtension;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _GradientTabIndicatorPainter(this, onChanged);
}

class _GradientTabIndicatorPainter extends BoxPainter {
  _GradientTabIndicatorPainter(this.decoration, VoidCallback? onChanged)
      : super(onChanged);

  final GradientTabIndicator decoration;

  static const double _fadeLineThickness = 1;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final Size? size = configuration.size;
    if (size == null) return;

    final double barTop = offset.dy + size.height - decoration.thickness;
    final double centerY = barTop + decoration.thickness / 2;
    final double left = offset.dx;
    final double fadeWidth = size.width + decoration.fadeExtension * 2;

    final Rect fadeRect = Rect.fromLTWH(
      left - decoration.fadeExtension,
      centerY - _fadeLineThickness / 2,
      fadeWidth,
      _fadeLineThickness,
    );
    final double edgeStop = decoration.fadeExtension / fadeWidth;
    final Paint fadePaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          Colors.transparent,
          heerrMagenta.withValues(alpha: 0.55),
          heerrMagenta.withValues(alpha: 0.55),
          Colors.transparent,
        ],
        stops: <double>[0, edgeStop, 1 - edgeStop, 1],
      ).createShader(fadeRect);
    canvas.drawRect(fadeRect, fadePaint);

    final Rect bar = Rect.fromLTWH(left, barTop, size.width, decoration.thickness);
    final Paint barPaint = Paint()..shader = decoration.gradient.createShader(bar);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bar, Radius.circular(decoration.thickness / 2)),
      barPaint,
    );
  }
}
