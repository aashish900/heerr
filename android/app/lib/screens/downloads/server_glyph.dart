import 'package:flutter/material.dart';

import '../../theme.dart';

/// Server illustration for the Downloads hero (DL2, DOWNLOADSSCREEN.md §2) —
/// the reference render (`assets/images/downloads_server.png`), shown as a
/// full-bleed hero image filling the left ~35-40% of the card (source design:
/// `Downloads Screen.png`) rather than a small circular thumbnail. A soft
/// magenta glow breathes behind it while [online] is true; offline dims the
/// image and drops the glow.
class ServerGlyph extends StatefulWidget {
  const ServerGlyph({required this.online, this.width = 130, super.key});

  final bool online;
  final double width;

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
        final double glow = widget.online ? 0.15 + 0.15 * _controller.value : 0.0;
        return SizedBox(
          width: widget.width,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (glow > 0)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: <Color>[
                        heerrMagenta.withValues(alpha: glow),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              Opacity(
                opacity: widget.online ? 1.0 : 0.5,
                child: Image.asset(ServerGlyph._assetPath, fit: BoxFit.cover),
              ),
            ],
          ),
        );
      },
    );
  }
}
