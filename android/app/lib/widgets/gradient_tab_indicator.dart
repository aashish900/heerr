import 'package:flutter/material.dart';

import '../theme.dart';

/// Tab indicator: a thick rounded magenta->violet gradient bar under the
/// selected label, centered over a thin faint magenta line spanning the
/// *entire* selected tab's width — matches the reference screenshot's
/// bold-bar-over-full-width-glow look. Requires `TabBarThemeData.indicatorSize
/// == TabBarIndicatorSize.tab` so the Decoration is handed the full tab rect
/// (not just the label's), since one Decoration paint() call only gets one
/// size and both layers need to share it.
class GradientTabIndicator extends Decoration {
  const GradientTabIndicator({
    this.gradient = heerrGradient,
    this.thickness = 3,
    this.fadeAlpha = 0.35,
    this.boldWidthFraction = 0.5,
  });

  final Gradient gradient;
  final double thickness;
  final double fadeAlpha;
  final double boldWidthFraction;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _GradientTabIndicatorPainter(this, onChanged);
}

class _GradientTabIndicatorPainter extends BoxPainter {
  _GradientTabIndicatorPainter(this.decoration, VoidCallback? onChanged)
      : super(onChanged);

  final GradientTabIndicator decoration;

  static const double _fadeLineThickness = 1;
  static const double _fadeTaper = 0.12;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final Size? size = configuration.size;
    if (size == null) return;

    final double barTop = offset.dy + size.height - decoration.thickness;
    final double centerY = barTop + decoration.thickness / 2;

    // Faint line spans the full tab width, tapering to transparent at the
    // very ends rather than a hard-edged cut.
    final Rect fadeRect = Rect.fromLTWH(
      offset.dx,
      centerY - _fadeLineThickness / 2,
      size.width,
      _fadeLineThickness,
    );
    final Color fadeColor = heerrMagenta.withValues(alpha: decoration.fadeAlpha);
    final Paint fadePaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[Colors.transparent, fadeColor, fadeColor, Colors.transparent],
        stops: const <double>[0, _fadeTaper, 1 - _fadeTaper, 1],
      ).createShader(fadeRect);
    canvas.drawRect(fadeRect, fadePaint);

    // Bold rounded gradient bar, narrower and centered within the tab.
    final double barWidth = size.width * decoration.boldWidthFraction;
    final Rect bar = Rect.fromLTWH(
      offset.dx + (size.width - barWidth) / 2,
      barTop,
      barWidth,
      decoration.thickness,
    );
    final Paint barPaint = Paint()..shader = decoration.gradient.createShader(bar);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bar, Radius.circular(decoration.thickness / 2)),
      barPaint,
    );
  }
}
