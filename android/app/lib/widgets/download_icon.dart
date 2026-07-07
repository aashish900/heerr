import 'package:flutter/material.dart';

import '../theme.dart';

/// Download icon rendered from a PNG asset, colourised via [BlendMode.srcIn].
///
/// [filled] = true  → heerr-green tint (active / marked / already downloaded).
/// [filled] = false → [color] tint, defaulting to [IconTheme] colour → white.
///
/// Behaves like a regular [Icon] in any context that sets [IconTheme]
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
    final Color c = filled
        ? heerrGreen
        : (color ?? IconTheme.of(context).color ?? Colors.white);
    return Image.asset(
      'assets/icons/download_file.png',
      width: size,
      height: size,
      color: c,
      colorBlendMode: BlendMode.srcIn,
    );
  }
}
