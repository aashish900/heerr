import 'package:flutter/material.dart';

/// Circular "glass" surface used for chrome buttons in the Now Playing
/// redesign (NOWPLAYING.md NP2+): a faint translucent white fill with a
/// hairline border, floating over the blurred [NowPlayingBackground] instead
/// of a flat `IconButton`. Disabled (null [onPressed]) dims the glyph rather
/// than hiding the button — matches the mockup's always-visible placeholder
/// affordances (e.g. the audio-output icon, which has no wiring yet).
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 40,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final Widget button = Material(
      color: Colors.white.withValues(alpha: 0.06),
      shape: CircleBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            color: enabled ? Colors.white : Colors.white38,
            size: size * 0.5,
          ),
        ),
      ),
    );
    final String? label = tooltip;
    return label == null ? button : Tooltip(message: label, child: button);
  }
}
