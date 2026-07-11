import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/seed_track.dart';
import '../../models/subsonic/song.dart';
import '../../player/playback_actions.dart';
import '../../providers/library/starred_songs.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/library_cover_art.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/song_row_actions.dart';

/// Starred-songs list — the Favorites Quick Access card's destination
/// (HOMESCREEN.md task 5). Rows reuse the same building blocks as the
/// playlist screen (LibraryCoverArt + SongRowActions) and play through the
/// shared `playAllSongsFromSubsonic` path — no new playback entry point.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Song>> starred = ref.watch(starredSongsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(starredSongsProvider);
          return ref
              .read(starredSongsProvider.future)
              .catchError((_) => const <Song>[]);
        },
        child: starred.when(
          loading: () => ListView(
            children: const <Widget>[
              SkeletonTile(),
              SkeletonTile(),
              SkeletonTile(),
              SkeletonTile(),
              SkeletonTile(),
            ],
          ),
          error: (Object e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: <Widget>[
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.wifi_off_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      const Text("Can't load favorites"),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        key: const Key('favorites-retry'),
                        onPressed: () => ref.invalidate(starredSongsProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          data: (List<Song> songs) {
            if (songs.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const <Widget>[
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 96),
                    child: EmptyState(
                      icon: Icons.favorite_outline,
                      title: 'No favorites yet',
                      subtitle: 'Star songs to collect them here.',
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: songs.length,
              itemBuilder: (BuildContext c, int i) {
                final Song s = songs[i];
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
                  trailing: SongRowActions(
                    song: s,
                    findSimilarSeed: seedForSong(s),
                    editMetadataSong: s,
                    deleteFromServerSong: s,
                  ),
                  onTap: () => playAllSongsFromSubsonic(
                    ref,
                    c,
                    songs,
                    startIndex: i,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
