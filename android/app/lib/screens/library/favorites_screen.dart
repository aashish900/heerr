import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/subsonic/playlist.dart';
import '../../providers/library/favourites.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton.dart';
import 'playlist_detail_screen.dart';

/// Favorites Quick Access card's destination (HOMESCREEN.md task 5).
///
/// Favorites is a real Navidrome playlist named `Favourites`
/// ([kFavouritesPlaylistName]), not the Subsonic star primitive — an
/// earlier decision (DECISIONLOG "Subsonic star primitive for Favourites")
/// rejected `star.view`/`getStarred2.view` for this exact surface because
/// starred items don't render as an openable/playable list in Navidrome.
/// The heart icon elsewhere in the app (`PlaylistMutations.toggleFavourite`)
/// already maintains this playlist. This screen just resolves it and hands
/// off to [PlaylistDetailScreen] — no separate row/play UI to maintain.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Playlist?> fav = ref.watch(favouritesPlaylistProvider);
    return fav.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Favorites')),
        body: const SkeletonList(),
      ),
      error: (Object e, _) => Scaffold(
        appBar: AppBar(title: const Text('Favorites')),
        body: RefreshIndicator(
          onRefresh: () async => ref.invalidate(favouritesPlaylistProvider),
          child: ListView(
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
                        onPressed: () =>
                            ref.invalidate(favouritesPlaylistProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (Playlist? playlist) {
        if (playlist == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Favorites')),
            body: RefreshIndicator(
              onRefresh: () async => ref.invalidate(favouritesPlaylistProvider),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const <Widget>[
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 96),
                    child: EmptyState(
                      icon: Icons.favorite_outline,
                      title: 'No favorites yet',
                      subtitle: 'Heart songs to collect them here.',
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return PlaylistDetailScreen(playlistId: playlist.id);
      },
    );
  }
}
