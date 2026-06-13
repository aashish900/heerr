import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_error.dart';
import '../../models/subsonic/playlist.dart';
import '../../models/subsonic/song.dart';
import '../../offline/offline_manifest.dart';
import '../../offline/offline_marker.dart';
import '../../player/playback_actions.dart';
import '../../player/player_provider.dart';
import '../../providers/library/library_playlist.dart';
import '../../providers/library/playlist_mutations.dart';
import '../../providers/settings.dart';
import '../../theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_snackbar.dart';
import '../../widgets/library_cover_art.dart';
import '../../widgets/playlist_dialogs.dart';
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

    final OfflineManifest? manifest =
        ref.watch(offlineManifestProvider).valueOrNull;
    final bool isMarked =
        manifest?.markedPlaylists.contains(playlistId) ?? false;

    final SettingsValue? settings =
        ref.watch(settingsProvider).valueOrNull;
    final Playlist? loaded = async.valueOrNull;
    final bool canEdit = loaded != null &&
        settings != null &&
        loaded.owner != null &&
        loaded.owner == settings.navidromeUsername;

    return Scaffold(
      appBar: AppBar(
        title: Text(async.maybeWhen<String>(
          data: (Playlist p) => p.name,
          orElse: () => 'Playlist',
        )),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              isMarked
                  ? Icons.download_for_offline
                  : Icons.download_for_offline_outlined,
              color: isMarked ? heerrGreen : null,
            ),
            tooltip:
                isMarked ? 'Unmark for offline' : 'Mark for offline',
            onPressed: () {
              final OfflineMarker n =
                  ref.read(offlineMarkerProvider.notifier);
              if (isMarked) {
                n.unmarkPlaylist(playlistId);
              } else {
                n.markPlaylist(playlistId);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow_outlined),
            tooltip: 'Play all',
            onPressed: () {
              final Playlist? p = async.valueOrNull;
              if (p == null) return;
              playAllSongsFromSubsonic(ref, context, p.entry);
            },
          ),
          if (canEdit)
            PopupMenuButton<_PlaylistAction>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Edit playlist',
              onSelected: (_PlaylistAction a) async {
                switch (a) {
                  case _PlaylistAction.rename:
                    await _onRename(context, ref, loaded);
                  case _PlaylistAction.delete:
                    await _onDelete(context, ref, loaded);
                }
              },
              itemBuilder: (BuildContext c) =>
                  const <PopupMenuEntry<_PlaylistAction>>[
                PopupMenuItem<_PlaylistAction>(
                  value: _PlaylistAction.rename,
                  child: Text('Rename…'),
                ),
                PopupMenuItem<_PlaylistAction>(
                  value: _PlaylistAction.delete,
                  child: Text('Delete…'),
                ),
              ],
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

  Future<void> _onRename(
    BuildContext context,
    WidgetRef ref,
    Playlist current,
  ) async {
    final RenamePlaylistResult? result = await RenamePlaylistDialog.show(
      context,
      initialName: current.name,
      initialPublic: current.public ?? false,
    );
    if (result == null || !context.mounted) return;
    try {
      await ref.read(playlistMutationsProvider.notifier).renamePlaylist(
        playlistId: current.id,
        name: result.name,
        makePublic: result.makePublic,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: kSnackBarDuration,
          content: Text('Playlist updated'),
        ),
      );
    } on ApiError catch (e) {
      if (!context.mounted) return;
      showApiError(context, e);
    }
  }

  Future<void> _onDelete(
    BuildContext context,
    WidgetRef ref,
    Playlist current,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('Delete playlist?'),
        content: Text(
          "Delete '${current.name}'? This cannot be undone.",
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(playlistMutationsProvider.notifier)
          .deletePlaylist(current.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: kSnackBarDuration,
          content: Text('Playlist deleted'),
        ),
      );
      // Pop back to the Library if we can; otherwise stay (the list-tab
      // refetch driven by invalidation will reflect the delete). Routed
      // via GoRouter.maybeOf so widget tests without a router ancestor
      // don't crash on the post-delete navigation (mirrors the create-
      // flow fail-soft in `_PlaylistsTab._onCreatePressed`).
      final GoRouter? router = GoRouter.maybeOf(context);
      if (router != null && router.canPop()) {
        router.pop();
      }
    } on ApiError catch (e) {
      if (!context.mounted) return;
      showApiError(context, e);
    }
  }
}

enum _PlaylistAction { rename, delete }

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
    final String? currentSubsonicId = ref
        .watch(currentMediaItemProvider)
        .valueOrNull
        ?.extras?['subsonicId'] as String?;
    final OfflineManifest? manifest =
        ref.watch(offlineManifestProvider).valueOrNull;
    // Top-down propagation: when the playlist itself is marked, every
    // entry shows the soft "scheduled" badge until sync produces a
    // real manifest entry. Mirrors the album-detail behavior.
    final bool containerMarked =
        manifest?.markedPlaylists.contains(playlist.id) ?? false;
    return ListView.builder(
      itemCount: playlist.entry.length + 1,
      itemBuilder: (BuildContext c, int i) {
        if (i == 0) return _PlaylistHeader(playlist: playlist);
        final int idx = i - 1;
        final Song s = playlist.entry[idx];
        final bool isCurrent = s.id == currentSubsonicId;
        final OfflineSongEntry? offline = manifest?.songs[s.id];
        return ListTile(
          leading: LibraryCoverArt(coverArtId: s.coverArt, size: 40),
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
          subtitle: Text(
            s.artist ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: _buildSongTrailing(isCurrent, offline, containerMarked),
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

  Widget? _buildSongTrailing(
    bool isCurrent,
    OfflineSongEntry? offline,
    bool containerMarked,
  ) {
    if (isCurrent) {
      return const Icon(Icons.play_arrow, color: heerrGreen);
    }
    if (offline == null) {
      if (containerMarked) {
        return const Icon(
          Icons.download_for_offline_outlined,
          size: 18,
        );
      }
      return null;
    }
    switch (offline.state) {
      case OfflineSongState.ready:
        return const Icon(
          Icons.download_done,
          color: heerrGreen,
          size: 18,
        );
      case OfflineSongState.downloading:
        return const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case OfflineSongState.queued:
        return const Icon(Icons.schedule, size: 18);
      case OfflineSongState.failed:
        return Tooltip(
          message: offline.lastError ?? 'Download failed',
          child: const Icon(
            Icons.error_outline,
            color: Colors.redAccent,
            size: 18,
          ),
        );
    }
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
