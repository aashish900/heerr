import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'waveform_strip.dart';

/// Test seam for the bar-breathing animation — a repeating [AnimationController]
/// never satisfies `pumpAndSettle`, so tests set this `false` (same shape as
/// `paletteExtractorOverride` / `heroArtFloatEnabled` in `now_playing_screen.dart`).
@visibleForTesting
bool waveformSeekBarAnimateEnabled = true;

/// Premium seek control (NOWPLAYING.md NP5) replacing the Material [Slider]:
/// a deterministic waveform (seeded per track, same generator as
/// [WaveformStrip]) painted with the [heerrGradient], full-alpha up to the
/// playhead and dimmed after it, a thin white progress line, and a glowing
/// magenta thumb. Tap jumps directly; drag previews then commits on release —
/// both route through [onSeekStart] / [onSeekUpdate] / [onSeekEnd], the same
/// three-callback shape the old `Slider` used, so callers don't change.
class WaveformSeekBar extends StatefulWidget {
  const WaveformSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
    this.animate = false,
    this.seed = 0,
    this.height = 40,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeekStart;
  final ValueChanged<Duration> onSeekUpdate;
  final ValueChanged<Duration> onSeekEnd;

  /// Bar-breathing while the track is playing — pass `snapshot.isPlaying`.
  final bool animate;

  /// Seeds the bar-height sequence — pass something stable per track
  /// (e.g. `item.title.hashCode`).
  final int seed;

  final double height;

  @override
  State<WaveformSeekBar> createState() => _WaveformSeekBarState();
}

class _WaveformSeekBarState extends State<WaveformSeekBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  Duration? _dragValue;

  bool get _shouldAnimate => widget.animate && waveformSeekBarAnimateEnabled;

  @override
  void initState() {
    super.initState();
    if (_shouldAnimate) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(WaveformSeekBar old) {
    super.didUpdateWidget(old);
    if (_shouldAnimate && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!_shouldAnimate && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _seekable => widget.duration.inMilliseconds > 0;

  Duration _durationAt(double dx, double width) {
    final double clampedWidth = width <= 0 ? 1 : width;
    final double fraction = (dx / clampedWidth).clamp(0.0, 1.0);
    final int totalMs = widget.duration.inMilliseconds;
    return Duration(milliseconds: (fraction * totalMs).round());
  }

  String _fmt(Duration d) {
    final int total = d.inSeconds;
    final int m = total ~/ 60;
    final int s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final Duration position = widget.position;
    final Duration duration = widget.duration;
    final double playedFraction = duration.inMilliseconds <= 0
        ? 0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: <Widget>[
          Semantics(
            slider: true,
            value: _fmt(position),
            increasedValue: _fmt(position + const Duration(seconds: 10)),
            decreasedValue: _fmt(position - const Duration(seconds: 10)),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double width = constraints.maxWidth;
                return GestureDetector(
                  key: const Key('waveform-seek-bar-track'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: !_seekable
                      ? null
                      : (TapUpDetails d) {
                          final Duration value =
                              _durationAt(d.localPosition.dx, width);
                          widget.onSeekStart(value);
                          widget.onSeekEnd(value);
                        },
                  onHorizontalDragStart: !_seekable
                      ? null
                      : (DragStartDetails d) {
                          final Duration value =
                              _durationAt(d.localPosition.dx, width);
                          _dragValue = value;
                          widget.onSeekStart(value);
                        },
                  onHorizontalDragUpdate: !_seekable
                      ? null
                      : (DragUpdateDetails d) {
                          final Duration value =
                              _durationAt(d.localPosition.dx, width);
                          _dragValue = value;
                          widget.onSeekUpdate(value);
                        },
                  onHorizontalDragEnd: !_seekable
                      ? null
                      : (DragEndDetails d) {
                          widget.onSeekEnd(_dragValue ?? position);
                          _dragValue = null;
                        },
                  child: AnimatedBuilder(
                    animation: _ctrl,
                    builder: (BuildContext context, Widget? _) => CustomPaint(
                      size: Size(width, widget.height),
                      painter: _WaveformSeekPainter(
                        playedFraction: playedFraction,
                        seed: widget.seed,
                        phase: _shouldAnimate ? _ctrl.value * 2 * math.pi : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(_fmt(position),
                    style: Theme.of(context).textTheme.bodySmall),
                Text(_fmt(duration),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformSeekPainter extends CustomPainter {
  const _WaveformSeekPainter({
    required this.playedFraction,
    required this.seed,
    required this.phase,
  });

  final double playedFraction;
  final int seed;

  /// Animation phase in radians; null = static bars at their base height.
  final double? phase;

  static const double barWidth = 3;
  static const double gap = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final int count = (size.width / (barWidth + gap)).floor();
    if (count <= 0) return;
    final List<double> heights = WaveformStrip.barHeights(count, seed);
    final Rect fullRect = Offset.zero & size;
    final double playedX = playedFraction * size.width;
    final double? p = phase;

    for (int i = 0; i < count; i++) {
      double h = heights[i];
      if (p != null) {
        h = (h * (0.55 + 0.45 * math.sin(p + i * 0.9))).clamp(0.10, 1.0);
      }
      final double x = i * (barWidth + gap);
      final bool played = x < playedX;
      final double barHeight = h * size.height;
      final Paint paint = Paint()
        ..shader = heerrGradient.createShader(fullRect)
        ..color = Colors.white.withValues(alpha: played ? 1.0 : 0.35);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - barHeight, barWidth, barHeight),
          const Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }

    final double baselineY = size.height - 1;
    if (playedX > 0) {
      canvas.drawLine(
        Offset(0, baselineY),
        Offset(playedX, baselineY),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2,
      );
    }

    final Offset thumbCenter = Offset(playedX, baselineY);
    canvas.drawCircle(
      thumbCenter,
      8,
      Paint()
        ..color = heerrMagenta.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(thumbCenter, 5, Paint()..color = heerrMagenta);
  }

  @override
  bool shouldRepaint(_WaveformSeekPainter old) =>
      old.playedFraction != playedFraction ||
      old.seed != seed ||
      old.phase != phase;
}
