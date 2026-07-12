import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Decorative waveform (redesign — HOMESCREEN.md task 2). Bar heights are
/// pseudo-random but deterministic per [seed], so a given track always
/// renders the same shape and rebuilds don't flicker.
///
/// [animate] adds the equalizer motion from the home-screen widget's
/// concept art: bars breathe around their base height while a track plays.
/// [gradient] paints the bars with a shader (e.g. [heerrGradient]) instead
/// of the flat [color].
///
/// Not a progress indicator and not tappable — pair it with a real progress
/// bar where needed (Continue Listening card, MiniPlayer).
class WaveformStrip extends StatefulWidget {
  const WaveformStrip({
    super.key,
    this.height = 28,
    this.color = heerrMagenta,
    this.gradient,
    this.seed = 0,
    this.barWidth = 3,
    this.gap = 2,
    this.animate = false,
    this.progress,
  });

  final double height;
  final Color color;

  /// When set, bars are shader-painted with this gradient and [color] is
  /// ignored.
  final Gradient? gradient;

  /// Seeds the bar-height sequence — pass something stable per track
  /// (e.g. `title.hashCode`).
  final int seed;

  final double barWidth;
  final double gap;

  /// Animate the bars (equalizer breathing) — enable while playing only;
  /// a repeating animation never "settles" (mind `pumpAndSettle` in tests).
  final bool animate;

  /// DL2 (Downloads "Sync Center" hero): when set (0..1), bars up to this
  /// fraction paint at full [color]/[gradient]; the rest paint at low
  /// opacity, turning the decorative strip into a sync-progress indicator.
  /// Null (default) keeps the plain decorative rendering.
  final double? progress;

  /// Deterministic bar heights in 0.15..1.0 (fraction of [height]).
  /// LCG (numerical-recipes constants) rather than `Random(seed)` so the
  /// sequence is stable across Dart SDK versions. Shared with
  /// `WaveformSeekBar` so both widgets render the same shape per track.
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
  State<WaveformStrip> createState() => _WaveformStripState();
}

class _WaveformStripState extends State<WaveformStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(WaveformStrip old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.animate && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (BuildContext context, _) => CustomPaint(
          painter: _WaveformPainter(
            color: widget.color,
            gradient: widget.gradient,
            seed: widget.seed,
            barWidth: widget.barWidth,
            gap: widget.gap,
            phase: widget.animate ? _ctrl.value * 2 * math.pi : null,
            progress: widget.progress,
          ),
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.color,
    required this.gradient,
    required this.seed,
    required this.barWidth,
    required this.gap,
    required this.phase,
    required this.progress,
  });

  final Color color;
  final Gradient? gradient;
  final int seed;
  final double barWidth;
  final double gap;

  /// Animation phase in radians; null = static bars at their base height.
  final double? phase;

  /// DL2: fraction (0..1) of bars, by index, painted at full opacity; the
  /// rest painted dim. Null = plain decorative rendering (no dimming).
  final double? progress;

  static const double _dimAlpha = 0.25;

  @override
  void paint(Canvas canvas, Size size) {
    final int count = (size.width / (barWidth + gap)).floor();
    if (count <= 0) return;
    final List<double> heights = WaveformStrip.barHeights(count, seed);
    final Paint filledPaint = Paint();
    final Gradient? g = gradient;
    if (g != null) {
      filledPaint.shader = g.createShader(Offset.zero & size);
    } else {
      filledPaint.color = color;
    }
    final Paint dimPaint = Paint()..color = color.withValues(alpha: _dimAlpha);
    final double? p = phase;
    final double? prog = progress;
    final int filledCount = prog == null ? -1 : (prog.clamp(0, 1) * count).round();
    for (int i = 0; i < count; i++) {
      double h = heights[i];
      if (p != null) {
        // Equalizer breathing: each bar oscillates around its base height,
        // phase-shifted by index so the strip ripples instead of pulsing.
        h = (h * (0.55 + 0.45 * math.sin(p + i * 0.9))).clamp(0.10, 1.0);
      }
      final double px = h * size.height;
      final double x = i * (barWidth + gap);
      final Paint paint = prog == null || i < filledCount ? filledPaint : dimPaint;
      // Baseline-anchored (bars grow up from the bottom), not vertically
      // centered — matches the home-screen widget's waveform
      // (widget_wave_*.xml, generated by tool/gen_widget_wave.py), which
      // this strip is meant to visually echo.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - px, barWidth, px),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.color != color ||
      old.gradient != gradient ||
      old.seed != seed ||
      old.barWidth != barWidth ||
      old.gap != gap ||
      old.phase != phase ||
      old.progress != progress;
}
