import 'package:flutter/material.dart';

/// Brand header row: the heerr app-icon mark + wordmark. Sits as the Home
/// AppBar title (redesign — see docs/HOMESCREEN.md task 1). The mark reuses
/// `assets/icon.png` (the shipped app icon is the source of truth for the
/// brand mark — same rationale as the widget-logo extraction, DECISIONLOG
/// 2026-07-10).
class HeerrLogo extends StatelessWidget {
  const HeerrLogo({super.key, this.markSize = 32, this.showWordmark = true});

  /// Side length of the square logo mark.
  final double markSize;

  /// When false, renders the mark alone — the Library header pairs the mark
  /// with a compact greeting instead of the wordmark (LIBRARYSCREEN.md §1).
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final Widget mark = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/icon.png',
        width: markSize,
        height: markSize,
        fit: BoxFit.cover,
        // A load failure must never blow up the AppBar with a
        // RenderErrorBox — fall back to a fixed-size music glyph.
        errorBuilder: (_, _, _) => SizedBox(
          width: markSize,
          height: markSize,
          child: const Icon(Icons.music_note),
        ),
      ),
    );
    if (!showWordmark) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        mark,
        const SizedBox(width: 10),
        Text(
          'heerr',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}
