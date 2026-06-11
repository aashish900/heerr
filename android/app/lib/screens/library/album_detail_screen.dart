import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_error.dart';
import '../../models/subsonic/album.dart';
import '../../models/subsonic/song.dart';
import '../../providers/library/library_album.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/library_cover_art.dart';
import '../../widgets/skeleton.dart';

/// Album detail. Header with cover + name + artist + year above the song
/// list. Song-tap and "play all" actions land at J2 — at I1 they're no-ops.
class AlbumDetailScreen extends ConsumerWidget {
  const AlbumDetailScreen({required this.albumId, super.key});

  final String albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Album> async = ref.watch(libraryAlbumProvider(albumId));

    return Scaffold(
      appBar: AppBar(
        title: Text(async.maybeWhen<String>(
          data: (Album a) => a.name,
          orElse: () => 'Album',
        )),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.play_arrow_outlined),
            tooltip: 'Play all',
            onPressed: () {
              // J2 wires the player. I1 is a no-op placeholder.
            },
          ),
        ],
      ),
      body: async.when(
        loading: () => const SkeletonList(count: 6),
        error: (Object e, _) => Center(
          child: Text(e is ApiError ? e.message : 'Error: $e'),
        ),
        data: (Album a) => _Body(album: a),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    if (album.song.isEmpty) {
      return const EmptyState(
        icon: Icons.music_note_outlined,
        title: 'No songs',
        subtitle: 'This album has no tracks.',
      );
    }
    return ListView.builder(
      itemCount: album.song.length + 1,
      itemBuilder: (BuildContext c, int i) {
        if (i == 0) return _AlbumHeader(album: album);
        final Song s = album.song[i - 1];
        return ListTile(
          leading: Text(
            s.track == null ? '' : '${s.track}',
            style: Theme.of(c).textTheme.bodyMedium,
          ),
          title: Text(
            s.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: s.duration == null
              ? null
              : Text(_formatDuration(s.duration!)),
          // onTap wired at J2.
        );
      },
    );
  }

  String _formatDuration(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _AlbumHeader extends StatelessWidget {
  const _AlbumHeader({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LibraryCoverArt(coverArtId: album.coverArt, size: 120),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  album.name,
                  style: tt.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (album.artist != null)
                  Text(
                    album.artist!,
                    style: tt.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (album.year != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    '${album.year}',
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
