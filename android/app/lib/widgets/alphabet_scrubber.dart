import 'package:flutter/material.dart';

import '../theme.dart';

/// Right-edge A–Z index scrubber (X4, LIBRARYSCREEN.md §4). Tap or drag
/// along the strip fires [onLetter] with the letter under the finger;
/// the parent owns the scroll jump. Rendered only when the tab's sort is
/// alphabetical — the letter → index mapping is meaningless otherwise.
class AlphabetScrubber extends StatelessWidget {
  const AlphabetScrubber({
    required this.onLetter,
    this.activeLetter,
    super.key,
  });

  /// `#` bucket (leading digit/symbol) followed by A–Z — matches the
  /// case-insensitive sort order used by the Library tabs (digits and
  /// symbols compare below letters in `_byNameCi`).
  static const List<String> letters = <String>[
    '#', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  final ValueChanged<String> onLetter;
  final String? activeLetter;

  /// Maps a vertical touch position within the strip to its letter.
  /// Visible for tests.
  static String letterForDy(double dy, double height) {
    if (height <= 0) return letters.first;
    final int index =
        (dy / height * letters.length).floor().clamp(0, letters.length - 1);
    return letters[index];
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (BuildContext c, BoxConstraints constraints) {
        final double height = constraints.maxHeight;
        void handle(Offset localPosition) {
          onLetter(letterForDy(localPosition.dy, height));
        }

        return GestureDetector(
          key: const Key('alphabet-scrubber'),
          behavior: HitTestBehavior.opaque,
          onTapDown: (TapDownDetails d) => handle(d.localPosition),
          onVerticalDragUpdate: (DragUpdateDetails d) =>
              handle(d.localPosition),
          child: Column(
            children: <Widget>[
              // Each bucket flexes so the strip fits any height without
              // overflowing; FittedBox shrinks the glyph when squeezed.
              for (final String l in letters)
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      l,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: l == activeLetter
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: l == activeLetter
                            ? heerrMagenta
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// First list index the scrubber should land on for [letter], given
/// case-insensitively sorted [names]. Returns the first exact-bucket match,
/// else the first entry sorting *after* the bucket (nearest-jump, Spotify
/// behavior), else null for an empty list.
int? scrubTargetIndex(List<String> names, String letter) {
  if (names.isEmpty) return null;
  String bucketOf(String name) {
    if (name.isEmpty) return '#';
    final String first = name[0].toUpperCase();
    return (first.compareTo('A') >= 0 && first.compareTo('Z') <= 0)
        ? first
        : '#';
  }

  int bucketRank(String bucket) =>
      bucket == '#' ? 0 : bucket.codeUnitAt(0) - 'A'.codeUnitAt(0) + 1;

  final int want = bucketRank(letter);
  for (int i = 0; i < names.length; i++) {
    if (bucketRank(bucketOf(names[i])) >= want) return i;
  }
  // Everything sorts before the bucket → land at the end.
  return names.length - 1;
}
