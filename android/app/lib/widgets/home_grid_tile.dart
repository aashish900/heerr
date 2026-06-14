import 'package:flutter/material.dart';

import 'library_cover_art.dart';

/// Compact 2-column tile for the Home quick-access grid. 56 px square
/// cover-art flush-left, single-line title flowing into the remaining
/// width. Spotify-style dark-surface card with rounded corners.
class HomeGridTile extends StatelessWidget {
  const HomeGridTile({
    required this.title,
    required this.coverArtId,
    required this.onTap,
    super.key,
  });

  final String title;
  final String? coverArtId;
  final VoidCallback onTap;

  static const double _kCoverSize = 56;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: _kCoverSize,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LibraryCoverArt(
                coverArtId: coverArtId,
                size: _kCoverSize,
                borderRadius: 0,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
