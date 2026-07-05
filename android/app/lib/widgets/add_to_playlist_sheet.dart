import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_error.dart';
import '../models/seed_track.dart';
import '../models/subsonic/playlist.dart';
import '../models/subsonic/song.dart';
import '../player/playback_actions.dart';
import '../providers/library/library_delete.dart';
import '../providers/library/library_playlists.dart';
import '../providers/library/playlist_mutations.dart';
import '../providers/recommendations.dart';
import '../providers/server_creds.dart';
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
    this.queueSongs = const <Song>[],
    this.onRemoveFromPlaylist,
    this.removeFromPlaylistName,
    this.deleteFromServerSong,
    super.key,
  });

  final List<String> songIds;

  /// #35: when non-empty, renders an "Add to queue" entry that appends
  /// these songs to the Now Playing queue via [addSongsToQueue]. Callers
  /// that have full [Song] objects pass them here (song-row long-presses
  /// pass one, the album-level entry passes the album's tracklist); the
  /// Now Playing screen leaves it empty — queueing the track that is
  /// already playing is a no-op the user doesn't need.
  final List<Song> queueSongs;

  /// When non-null, renders a "Remove from [removeFromPlaylistName]" destructive
  /// tile at the top of the sheet. Only shown when the caller knows the user
  /// owns the playlist (gate is the caller's responsibility).
  final Future<void> Function()? onRemoveFromPlaylist;

  /// Display name for the playlist used in the remove tile label.
  final String? removeFromPlaylistName;

  /// When non-null, renders a "Find similar →" entry at the top of the
  /// sheet. Tapping it sets [manualSeedProvider] to this seed and
  /// navigates to `/library/recommendations`. Passed by single-song
  /// callers (long-press on song rows); album-level / multi-song
  /// callers leave it null so the affordance doesn't appear.
  final SeedTrack? findSimilarSeed;

  /// W1 (#41): when non-null and the song carries a Subsonic `path`, renders
  /// a destructive "Delete from server…" tile at the bottom of the sheet.
  /// Single-song long-press callers pass their [Song]; album-level /
  /// multi-song callers leave it null.
  final Song? deleteFromServerSong;

  static Future<void> show({
    required BuildContext context,
    required List<String> songIds,
    SeedTrack? findSimilarSeed,
    List<Song> queueSongs = const <Song>[],
    Future<void> Function()? onRemoveFromPlaylist,
    String? removeFromPlaylistName,
    Song? deleteFromServerSong,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddToPlaylistSheet(
        songIds: songIds,
        findSimilarSeed: findSimilarSeed,
        queueSongs: queueSongs,
        onRemoveFromPlaylist: onRemoveFromPlaylist,
        removeFromPlaylistName: removeFromPlaylistName,
        deleteFromServerSong: deleteFromServerSong,
      ),
    );
  }

  /// #35: queue while the sheet is still mounted (the sheet's `ref` is
  /// only valid until pop), then close. [addSongsToQueue] resolves the
  /// root ScaffoldMessenger up front, so its snackbar outlives the pop.
  Future<void> _onAddToQueue(BuildContext sheetContext, WidgetRef ref) async {
    await addSongsToQueue(ref, sheetContext, queueSongs);
    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
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

  /// W1 (#41): confirm over the still-open sheet (the sheet's `ref` is only
  /// valid until pop), delete via [LibraryDelete], then pop + snackbar via
  /// the pre-captured messenger. On [ApiError] the sheet stays open.
  Future<void> _onDeleteFromServer(
    BuildContext sheetContext,
    WidgetRef ref,
    Song song,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete from server?'),
        content: Text(
          '"${song.title}" will be permanently deleted from the Navidrome '
          'library for every user. This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !sheetContext.mounted) return;
    try {
      await ref.read(libraryDeleteProvider.notifier).deleteFromServer(song);
      if (!sheetContext.mounted) return;
      final ScaffoldMessengerState messenger =
          ScaffoldMessenger.of(sheetContext);
      Navigator.of(sheetContext).pop();
      messenger.showSnackBar(
        SnackBar(
          duration: kSnackBarDuration,
          content: Text(
            'Deleted "${song.title}" from server — library updates after '
            'the next Navidrome scan',
          ),
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
    final ServerCreds settings = ref.watch(serverCredsProvider);
    final String? username = settings.navidromeUsername;
    final ColorScheme cs = Theme.of(context).colorScheme;

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
            if (onRemoveFromPlaylist != null) ...<Widget>[
              ListTile(
                key: const Key('add-to-playlist-remove'),
                leading: Icon(Icons.remove_circle_outline, color: cs.error),
                title: Text(
                  removeFromPlaylistName != null
                      ? 'Remove from ${removeFromPlaylistName!}'
                      : 'Remove from playlist',
                  style: TextStyle(color: cs.error),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  onRemoveFromPlaylist!();
                },
              ),
              const Divider(height: 1),
            ],
            if (queueSongs.isNotEmpty) ...<Widget>[
              ListTile(
                key: const Key('add-to-playlist-add-to-queue'),
                leading: const Icon(Icons.playlist_play),
                title: const Text('Add to queue'),
                subtitle: const Text('Play after the current queue'),
                onTap: () => _onAddToQueue(context, ref),
              ),
              const Divider(height: 1),
            ],
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
            if (deleteFromServerSong != null &&
                deleteFromServerSong!.path != null &&
                deleteFromServerSong!.path!.isNotEmpty) ...<Widget>[
              const Divider(height: 1),
              ListTile(
                key: const Key('add-to-playlist-delete-from-server'),
                leading: Icon(Icons.cloud_off_outlined, color: cs.error),
                title: Text(
                  'Delete from server…',
                  style: TextStyle(color: cs.error),
                ),
                subtitle:
                    const Text('Removes the file from the Navidrome library'),
                onTap: () =>
                    _onDeleteFromServer(context, ref, deleteFromServerSong!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
