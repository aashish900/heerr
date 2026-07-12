import 'package:flutter/material.dart';

import '../../theme.dart';

/// Minimal server-rack outline for the Downloads hero (DL2,
/// DOWNLOADSSCREEN.md §2) — Nothing-OS style: dark, thin strokes, no
/// photorealism. A soft magenta glow breathes slowly while [online] is true;
/// offline renders a static, dim outline with no glow.
class ServerGlyph extends StatefulWidget {
  const ServerGlyph({required this.online, this.size = 72, super.key});

  final bool online;
  final double size;

  @override
  State<ServerGlyph> createState() => _ServerGlyphState();
}

class _ServerGlyphState extends State<ServerGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void initState() {
    super.initState();
    if (widget.online) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(ServerGlyph old) {
    super.didUpdateWidget(old);
    if (widget.online && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.online && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _ServerGlyphPainter(
            online: widget.online,
            glowOpacity: widget.online ? 0.15 + 0.25 * _controller.value : 0,
          ),
        ),
      ),
    );
  }
}

class _ServerGlyphPainter extends CustomPainter {
  const _ServerGlyphPainter({required this.online, required this.glowOpacity});

  final bool online;
  final double glowOpacity;

  static const int _rackLines = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final Color lineColor = online ? heerrMagenta : Colors.white24;

    if (glowOpacity > 0) {
      final Paint glow = Paint()
        ..color = heerrMagenta.withValues(alpha: glowOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
      canvas.drawCircle(size.center(Offset.zero), size.width * 0.45, glow);
    }

    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = lineColor;

    final Rect rack = Rect.fromLTWH(
      size.width * 0.22,
      size.height * 0.15,
      size.width * 0.56,
      size.height * 0.7,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rack, const Radius.circular(8)),
      stroke,
    );

    final Paint dot = Paint()..color = lineColor;
    for (int i = 0; i < _rackLines; i++) {
      final double y = rack.top + rack.height * (0.22 + i * 0.28);
      canvas.drawLine(
        Offset(rack.left + 8, y),
        Offset(rack.right - 14, y),
        stroke,
      );
      canvas.drawCircle(Offset(rack.right - 8, y), 2, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _ServerGlyphPainter old) =>
      old.online != online || old.glowOpacity != glowOpacity;
}
