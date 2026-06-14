import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_error.dart';
import '../models/seed_track.dart';
import '../models/subsonic/playlist.dart';
import '../providers/library/library_playlists.dart';
import '../providers/library/playlist_mutations.dart';
import '../providers/recommendations.dart';
import '../providers/settings.dart';
import '../router.dart';
import 'error_snackbar.dart';
import 'playlist_dialogs.dart';

/// Modal bottom sheet shown when the user wants to add one or more songs
/// to a playlist. Two ways to land here in M3:
///   1. Long-press a song row (album detail, playlist detail, or the
///      library-search "Songs" sub-section).
///   2. Album detail AppBar overflow → "Add album to playlist…".
///
/// Body shape (top to bottom):
///   - Title bar with the song-count summary.
///   - "+ Create new playlist…" row → opens [CreatePlaylistDialog] and on
///     confirm calls `PlaylistMutations.createPlaylist(name, songIds)`.
///   - List of existing playlists from [libraryPlaylistsProvider],
///     filtered to those owned by `settings.navidromeUsername`. Tap a
///     row → `PlaylistMutations.addSongs(playlistId, songIds)`.
///
/// Sheet pop / snackbar policy:
///   - On success → pop the sheet first, then surface a confirmation
///     snackbar via the captured `ScaffoldMessenger`. Capturing happens
///     before the pop because the sheet's context becomes stale once
///     unmounted.
///   - On failure → leave the sheet open and route through
///     [showApiError]. Sheet stays so the user can retry without
///     re-discovering the entry point.
class AddToPlaylistSheet extends ConsumerWidget {
  const AddToPlaylistSheet({
    required this.songIds,
    this.findSimilarSeed,
    super.key,
  });

  final List<String> songIds;

  /// When non-null, renders a "Find similar →" entry at the top of the
  /// sheet. Tapping it sets [manualSeedProvider] to this seed and
  /// navigates to `/library/recommendations`. Passed by single-song
  /// callers (long-press on song rows); album-level / multi-song
  /// callers leave it null so the affordance doesn't appear.
  final SeedTrack? findSimilarSeed;

  static Future<void> show({
    required BuildContext context,
    required List<String> songIds,
    SeedTrack? findSimilarSeed,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddToPlaylistSheet(
        songIds: songIds,
        findSimilarSeed: findSimilarSeed,
      ),
    );
  }

  void _onFindSimilar(BuildContext sheetContext, WidgetRef ref) {
    final SeedTrack? seed = findSimilarSeed;
    if (seed == null) return;
    ref.read(manualSeedProvider.notifier).state = seed;
    Navigator.of(sheetContext).pop();
    final GoRouter? router = GoRouter.maybeOf(sheetContext);
    router?.push(Routes.libraryRecommendations);
  }

  String _songCountLabel() => _pluralise(songIds.length);

  static String _pluralise(int n) => n == 1 ? '1 song' : '$n songs';

  Future<void> _onCreateNew(BuildContext sheetContext, WidgetRef ref) async {
    final String? name = await CreatePlaylistDialog.show(sheetContext);
    if (name == null || !sheetContext.mounted) return;
    try {
      final Playlist created = await ref
          .read(playlistMutationsProvider.notifier)
          .createPlaylist(name: name, songIds: songIds);
      if (!sheetContext.mounted) return;
      final ScaffoldMessengerState messenger =
          ScaffoldMessenger.of(sheetContext);
      Navigator.of(sheetContext).pop();
      messenger.showSnackBar(
        SnackBar(
          duration: kSnackBarDuration,
          content: Text(
            "Created '${created.name}' with ${_songCountLabel()}",
          ),
        ),
      );
    } on ApiError catch (e) {
      if (!sheetContext.mounted) return;
      showApiError(sheetContext, e);
    }
  }

  Future<void> _onAddToExisting(
    BuildContext sheetContext,
    WidgetRef ref,
    Playlist playlist,
  ) async {
    try {
      final int added =
          await ref.read(playlistMutationsProvider.notifier).addSongs(
        playlistId: playlist.id,
        songIds: songIds,
      );
      if (!sheetContext.mounted) return;
      final ScaffoldMessengerState messenger =
          ScaffoldMessenger.of(sheetContext);
      Navigator.of(sheetContext).pop();
      final int skipped = songIds.length - added;
      final String msg;
      if (added == 0) {
        msg = "Already in '${playlist.name}'";
      } else if (skipped == 0) {
        msg = "Added ${_pluralise(added)} to '${playlist.name}'";
      } else {
        msg =
            "Added ${_pluralise(added)} to '${playlist.name}' ($skipped already there)";
      }
      messenger.showSnackBar(
        SnackBar(
          duration: kSnackBarDuration,
          content: Text(msg),
        ),
      );
    } on ApiError catch (e) {
      if (!sheetContext.mounted) return;
      showApiError(sheetContext, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Playlist>> playlistsAsync =
        ref.watch(libraryPlaylistsProvider);
    final SettingsValue? settings = ref.watch(settingsProvider).valueOrNull;
    final String? username = settings?.navidromeUsername;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Add ${_songCountLabel()} to playlist',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (findSimilarSeed != null) ...<Widget>[
              ListTile(
                key: const Key('add-to-playlist-find-similar'),
                leading: const Icon(Icons.recommend_outlined),
                title: const Text('Find similar →'),
                subtitle:
                    const Text('Recommendations seeded from this song'),
                onTap: () => _onFindSimilar(context, ref),
              ),
              const Divider(height: 1),
            ],
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Create new playlist…'),
              onTap: () => _onCreateNew(context, ref),
            ),
            const Divider(height: 1),
            Flexible(
              child: playlistsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (Object e, _) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Text(
                    e is ApiError ? e.message : 'Error: $e',
                  ),
                ),
                data: (List<Playlist> all) {
                  final List<Playlist> editable = <Playlist>[
                    for (final Playlist p in all)
                      if (p.owner != null &&
                          username != null &&
                          p.owner == username)
                        p,
                  ];
                  if (editable.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Text(
                        'No editable playlists yet. Tap "Create new playlist…" above.',
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: editable.length,
                    itemBuilder: (BuildContext c, int i) {
                      final Playlist p = editable[i];
                      return ListTile(
                        leading: const Icon(Icons.queue_music_outlined),
                        title: Text(p.name),
                        subtitle: p.songCount == null
                            ? null
                            : Text('${p.songCount} songs'),
                        onTap: () => _onAddToExisting(context, ref, p),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
