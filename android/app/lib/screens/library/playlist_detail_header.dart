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
                if (_metaLine(playlist) case final String meta?) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    meta,
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

  /// Header meta line: song count and/or total run time, joined with " · "
  /// (e.g. "12 songs · 1 hr 6 min"). Returns null when neither is known.
  static String? _metaLine(Playlist playlist) {
    final List<String> parts = <String>[
      if (playlist.songCount != null) '${playlist.songCount} songs',
      if (playlist.duration != null && playlist.duration! > 0)
        _formatRuntime(playlist.duration!),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Formats a whole-playlist run time (in seconds) as a coarse,
  /// human-readable duration: "47 min", "1 hr 6 min", "2 hr". Seconds are
  /// dropped — playlist totals are minutes-scale, not track-scale.
  static String _formatRuntime(int seconds) {
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    if (h > 0) {
      return m > 0 ? '$h hr $m min' : '$h hr';
    }
    if (m > 0) return '$m min';
    return '< 1 min';
  }
}
