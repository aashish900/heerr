import 'package:flutter/material.dart';

import '../theme.dart';

/// Decorative static waveform (redesign — HOMESCREEN.md task 2). Purely
/// visual: bar heights are pseudo-random but deterministic per [seed], so a
/// given track always renders the same shape and rebuilds don't flicker.
///
/// Not a progress indicator and not tappable — pair it with a real progress
/// bar where needed (Continue Listening card, MiniPlayer).
class WaveformStrip extends StatelessWidget {
  const WaveformStrip({
    super.key,
    this.height = 28,
    this.color = heerrMagenta,
    this.seed = 0,
    this.barWidth = 3,
    this.gap = 2,
  });

  final double height;
  final Color color;

  /// Seeds the bar-height sequence — pass something stable per track
  /// (e.g. `title.hashCode`).
  final int seed;

  final double barWidth;
  final double gap;

  /// Deterministic bar heights in 0.15..1.0 (fraction of [height]).
  /// LCG (numerical-recipes constants) rather than `Random(seed)` so the
  /// sequence is stable across Dart SDK versions. Visible for tests.
  @visibleForTesting
  static List<double> barHeights(int count, int seed) {
    int state = seed & 0x7fffffff;
    final List<double> out = <double>[];
    for (int i = 0; i < count; i++) {
      state = (1664525 * state + 1013904223) & 0x7fffffff;
      out.add(0.15 + 0.85 * (state / 0x7fffffff));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WaveformPainter(
          color: color,
          seed: seed,
          barWidth: barWidth,
          gap: gap,
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.color,
    required this.seed,
    required this.barWidth,
    required this.gap,
  });

  final Color color;
  final int seed;
  final double barWidth;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final int count = (size.width / (barWidth + gap)).floor();
    if (count <= 0) return;
    final List<double> heights = WaveformStrip.barHeights(count, seed);
    final Paint paint = Paint()..color = color;
    for (int i = 0; i < count; i++) {
      final double h = heights[i] * size.height;
      final double x = i * (barWidth + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, (size.height - h) / 2, barWidth, h),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.color != color ||
      old.seed != seed ||
      old.barWidth != barWidth ||
      old.gap != gap;
}
