part of 'playlist_detail_screen.dart';

enum _PlaylistAction { rename, delete }

class _PlaylistHeader extends StatelessWidget {
  const _PlaylistHeader({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LibraryCoverArt(coverArtId: playlist.coverArt, size: 120),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  playlist.name,
                  style: tt.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (playlist.owner != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'by ${playlist.owner}',
                    style: tt.bodyMedium,
                  ),
                ],
                if (playlist.songCount != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    '${playlist.songCount} songs',
                    style: tt.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
