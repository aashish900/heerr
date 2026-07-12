import 'package:flutter/material.dart';

import '../../theme.dart';

/// Server illustration for the Downloads hero (DL2, DOWNLOADSSCREEN.md §2) —
/// the reference render (`assets/images/downloads_server.png`). A soft
/// magenta glow breathes behind it while [online] is true; offline dims the
/// image and drops the glow.
class ServerGlyph extends StatefulWidget {
  const ServerGlyph({required this.online, this.size = 72, super.key});

  final bool online;
  final double size;

  static const String _assetPath = 'assets/images/downloads_server.png';

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
      builder: (BuildContext context, _) {
        final double glow = widget.online ? 0.25 + 0.35 * _controller.value : 0.0;
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: glow > 0
                ? <BoxShadow>[
                    BoxShadow(
                      color: heerrMagenta.withValues(alpha: glow),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.size * 0.18),
            child: Opacity(
              opacity: widget.online ? 1.0 : 0.5,
              child: Image.asset(ServerGlyph._assetPath, fit: BoxFit.cover),
            ),
          ),
        );
      },
    );
  }
}
