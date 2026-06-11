import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_error.dart';
import '../../models/subsonic/playlist.dart';
import '../../models/subsonic/song.dart';
import '../../player/playback_actions.dart';
import '../../providers/library/library_playlist.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/library_cover_art.dart';
import '../../widgets/skeleton.dart';

/// Playlist detail. Mirrors [AlbumDetailScreen]: header + song list. Tap a
/// song row → play the playlist starting at that song. "Play all" → play
/// from the top.
class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({required this.playlistId, super.key});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Playlist> async =
        ref.watch(libraryPlaylistProvider(playlistId));

    return Scaffold(
      appBar: AppBar(
        title: Text(async.maybeWhen<String>(
          data: (Playlist p) => p.name,
          orElse: () => 'Playlist',
        )),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.play_arrow_outlined),
            tooltip: 'Play all',
            onPressed: () {
              final Playlist? p = async.valueOrNull;
              if (p == null) return;
              playAllSongsFromSubsonic(ref, context, p.entry);
            },
          ),
        ],
      ),
      body: async.when(
        loading: () => const SkeletonList(count: 6),
        error: (Object e, _) => Center(
          child: Text(e is ApiError ? e.message : 'Error: $e'),
        ),
        data: (Playlist p) => _Body(playlist: p),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (playlist.entry.isEmpty) {
      return const EmptyState(
        icon: Icons.queue_music_outlined,
        title: 'Empty playlist',
        subtitle: 'No tracks added yet.',
      );
    }
    return ListView.builder(
      itemCount: playlist.entry.length + 1,
      itemBuilder: (BuildContext c, int i) {
        if (i == 0) return _PlaylistHeader(playlist: playlist);
        final int idx = i - 1;
        final Song s = playlist.entry[idx];
        return ListTile(
          leading: LibraryCoverArt(coverArtId: s.coverArt, size: 40),
          title: Text(
            s.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            s.artist ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => playAllSongsFromSubsonic(
            ref,
            context,
            playlist.entry,
            startIndex: idx,
          ),
        );
      },
    );
  }
}

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
