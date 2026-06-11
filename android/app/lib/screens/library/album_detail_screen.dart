import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_error.dart';
import '../../models/subsonic/album.dart';
import '../../models/subsonic/song.dart';
import '../../player/playback_actions.dart';
import '../../player/player_provider.dart';
import '../../providers/library/library_album.dart';
import '../../theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/library_cover_art.dart';
import '../../widgets/skeleton.dart';

/// Album detail. Header with cover + name + artist + year above the song
/// list. Song row tap = play the album starting at that song. AppBar
/// "Play all" = play the album from the top.
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
              final Album? a = async.valueOrNull;
              if (a == null) return;
              playAllSongsFromSubsonic(ref, context, a.song);
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

class _Body extends ConsumerWidget {
  const _Body({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (album.song.isEmpty) {
      return const EmptyState(
        icon: Icons.music_note_outlined,
        title: 'No songs',
        subtitle: 'This album has no tracks.',
      );
    }
    final String? currentSubsonicId = ref
        .watch(currentMediaItemProvider)
        .valueOrNull
        ?.extras?['subsonicId'] as String?;
    return ListView.builder(
      itemCount: album.song.length + 1,
      itemBuilder: (BuildContext c, int i) {
        if (i == 0) return _AlbumHeader(album: album);
        final int idx = i - 1;
        final Song s = album.song[idx];
        final bool isCurrent = s.id == currentSubsonicId;
        return ListTile(
          leading: Text(
            s.track == null ? '' : '${s.track}',
            style: Theme.of(c).textTheme.bodyMedium?.copyWith(
                  color: isCurrent ? heerrGreen : null,
                  fontWeight: isCurrent ? FontWeight.w600 : null,
                ),
          ),
          title: Text(
            s.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: isCurrent
                ? const TextStyle(
                    color: heerrGreen,
                    fontWeight: FontWeight.w600,
                  )
                : null,
          ),
          subtitle: s.duration == null
              ? null
              : Text(_formatDuration(s.duration!)),
          trailing: isCurrent
              ? const Icon(Icons.play_arrow, color: heerrGreen)
              : null,
          onTap: () => playAllSongsFromSubsonic(
            ref,
            context,
            album.song,
            startIndex: idx,
          ),
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
