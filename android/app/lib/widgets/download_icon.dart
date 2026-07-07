import 'package:flutter/material.dart';

const Color _kHeerrGreen = Color(0xFF1DB954);

/// Circle with a rounded-chevron down-arrow — no horizontal bar.
///
/// [filled] = true  → heerr-green disc, near-black arrow (active / marked).
/// [filled] = false → circle outline + arrow outline in [color] (inactive).
///
/// When [color] is omitted the ambient [IconTheme] colour is used, so this
/// widget behaves like a regular [Icon] in any context that sets [IconTheme]
/// (NavigationBar, IconButton, ListTile.secondary, etc.).
class DownloadIcon extends StatelessWidget {
  const DownloadIcon({
    super.key,
    required this.filled,
    this.color,
    this.size = 24.0,
  });

  final bool filled;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color c =
        color ?? IconTheme.of(context).color ?? Colors.white;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DownloadPainter(filled: filled, color: c),
      ),
    );
  }
}

class _DownloadPainter extends CustomPainter {
  const _DownloadPainter({required this.filled, required this.color});

  final bool filled;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    // ── Circle ────────────────────────────────────────────────────────
    final double circleR = size.width * 0.458; // ≈ 11 / 24
    final Paint circlePaint = Paint()
      ..color = filled ? _kHeerrGreen : color
      ..strokeWidth = size.width * 0.063 // ≈ 1.5 / 24
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke;
    canvas.drawCircle(Offset(cx, cy), circleR, circlePaint);

    // ── Arrow (20 % thicker than reference, shaft joined to chevron) ──
    final Color arrowColor =
        filled ? const Color(0xFF1A1A1A) : color;
    final double sw = size.width * 0.100; // ≈ 2.4 / 24

    final Paint arrowPaint = Paint()
      ..color = arrowColor
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Key y-coordinates (proportional so the icon scales with [size])
    final double shaftTopY = size.height * 0.250; // top of shaft
    final double apexY     = size.height * 0.688; // chevron apex (bottom of V)
    final double armY      = size.height * 0.510; // where chevron arms end
    final double armX      = size.width  * 0.300; // half-spread of chevron

    // Single connected path: shaft → apex → right arm, then back to left arm.
    // The round join at the apex makes the shaft-to-chevron transition smooth.
    final Path path = Path()
      ..moveTo(cx, shaftTopY)
      ..lineTo(cx, apexY)          // shaft
      ..lineTo(cx + armX, armY)    // right arm
      ..moveTo(cx, apexY)
      ..lineTo(cx - armX, armY);   // left arm

    canvas.drawPath(path, arrowPaint);
  }

  @override
  bool shouldRepaint(_DownloadPainter old) =>
      old.filled != filled || old.color != color;
}
