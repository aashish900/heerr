import 'package:flutter/material.dart';

import '../../models/subsonic/album.dart';
import '../../theme.dart';
import '../../widgets/library_cover_art.dart';

/// One cell of the Albums-tab grid (X3, LIBRARYSCREEN.md §1): square cover,
/// title, artist, song count, and a magenta check badge when the album is
/// marked for offline.
class AlbumGridCard extends StatelessWidget {
  const AlbumGridCard({
    required this.album,
    required this.downloaded,
    this.onTap,
    super.key,
  });

  final Album album;
  final bool downloaded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    final ColorScheme cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // The cover fills the cell width; LayoutBuilder feeds the actual
          // cell size into LibraryCoverArt's fixed-size contract.
          LayoutBuilder(
            builder: (BuildContext c, BoxConstraints constraints) {
              final double side = constraints.maxWidth;
              return Stack(
                children: <Widget>[
                  LibraryCoverArt(
                    coverArtId: album.coverArt,
                    size: side,
                    borderRadius: 10,
                  ),
                  if (downloaded)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle,
                          key: Key('album-downloaded-badge-${album.id}'),
                          size: 18,
                          color: heerrMagenta,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            album.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (album.artist != null)
            Text(
              album.artist!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          if (album.songCount != null)
            Text(
              '${album.songCount} songs',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
