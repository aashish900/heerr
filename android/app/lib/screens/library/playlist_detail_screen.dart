import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_error.dart';
import '../../models/seed_track.dart';
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
import '../../widgets/add_to_playlist_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_snackbar.dart';
import '../../widgets/library_cover_art.dart';
import '../../widgets/playlist_dialogs.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/song_row_actions.dart';

/// Playlist detail. Mirrors [AlbumDetailScreen] for the read path: header
/// + song list, tap to play. M2 added rename / delete via the AppBar
/// overflow. M4 layers an edit mode on top — pencil icon in the AppBar
/// flips the song list into a [ReorderableListView] with per-row delete
/// toggles; the check icon commits via `PlaylistMutations.reorder` /
/// `removeSongsAtIndices`. Edit is gated on `owner == navidromeUsername`
/// (same rule as the M2 rename / delete affordances).
class PlaylistDetailScreen extends ConsumerStatefulWidget {
  const PlaylistDetailScreen({required this.playlistId, super.key});

  final String playlistId;

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  bool _isEditing = false;

  /// Working copy of the song list while edit mode is active. Drag-reorder
  /// mutates this; rows marked for removal stay in place so the visible
  /// indices don't shift mid-edit.
  List<Song> _editOrder = const <Song>[];

  /// Song ids the user has tapped the delete handle on. Kept by id (not
  /// index) so reordering doesn't invalidate the set.
  final Set<String> _removedIds = <String>{};

  /// Guards the Save (check) action against double-tap while the mutation
  /// is in flight.
  bool _committing = false;

  void _enterEdit(Playlist p) {
    setState(() {
      _isEditing = true;
      _editOrder = List<Song>.from(p.entry);
      _removedIds.clear();
    });
  }

  void _exitEdit() {
    setState(() {
      _isEditing = false;
      _editOrder = const <Song>[];
      _removedIds.clear();
    });
  }

  /// True when [_editOrder] or [_removedIds] diverge from [original]. Used
  /// to decide whether to surface the discard-confirmation dialog on back.
  bool _hasPendingEdits(Playlist original) {
    if (_removedIds.isNotEmpty) return true;
    if (_editOrder.length != original.entry.length) return true;
    for (int i = 0; i < _editOrder.length; i++) {
      if (_editOrder[i].id != original.entry[i].id) return true;
    }
    return false;
  }

  Future<bool> _confirmDiscard() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your pending edits will be lost.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _onCommit(Playlist original) async {
    if (_committing) return;
    setState(() => _committing = true);
    try {
      // Indices of removed songs in the ORIGINAL list — that's the
      // coordinate space `songIndexToRemove` is indexed against on the
      // wire (M1 `removeSongsAtIndices` sorts descending internally).
      final List<int> removedOrigIndices = <int>[
        for (int i = 0; i < original.entry.length; i++)
          if (_removedIds.contains(original.entry[i].id)) i,
      ];

      final List<String> survivingFromEdit = <String>[
        for (final Song s in _editOrder)
          if (!_removedIds.contains(s.id)) s.id,
      ];
      final List<String> survivingFromOrig = <String>[
        for (final Song s in original.entry)
          if (!_removedIds.contains(s.id)) s.id,
      ];

      bool sameOrder =
          survivingFromEdit.length == survivingFromOrig.length;
      if (sameOrder) {
        for (int i = 0; i < survivingFromEdit.length; i++) {
          if (survivingFromEdit[i] != survivingFromOrig[i]) {
            sameOrder = false;
            break;
          }
        }
      }
      final bool isReorder = !sameOrder;

      if (!isReorder && removedOrigIndices.isEmpty) {
        // Edit mode entered but nothing changed → quiet exit.
        _exitEdit();
        return;
      }

      final PlaylistMutations notifier =
          ref.read(playlistMutationsProvider.notifier);
      if (isReorder) {
        await notifier.reorder(
          playlistId: widget.playlistId,
          newSongIdOrder: survivingFromEdit,
        );
      } else {
        await notifier.removeSongsAtIndices(
          playlistId: widget.playlistId,
          indices: removedOrigIndices,
        );
      }
      if (!mounted) return;
      _exitEdit();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: kSnackBarDuration,
          content: Text('Playlist updated'),
        ),
      );
    } on ApiError catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) {
        setState(() => _committing = false);
      }
    }
  }

  Future<void> _onRename(Playlist current) async {
    final RenamePlaylistResult? result = await RenamePlaylistDialog.show(
      context,
      initialName: current.name,
      initialPublic: current.public ?? false,
    );
    if (result == null || !mounted) return;
    try {
      await ref.read(playlistMutationsProvider.notifier).renamePlaylist(
        playlistId: current.id,
        name: result.name,
        makePublic: result.makePublic,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: kSnackBarDuration,
          content: Text('Playlist updated'),
        ),
      );
    } on ApiError catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  Future<void> _onDelete(Playlist current) async {
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
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(playlistMutationsProvider.notifier)
          .deletePlaylist(current.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: kSnackBarDuration,
          content: Text('Playlist deleted'),
        ),
      );
      // GoRouter.maybeOf so widget tests without a router ancestor don't
      // crash on the post-delete navigation (mirrors the M2 create-flow
      // fail-soft in `_PlaylistsTab._onCreatePressed`).
      final GoRouter? router = GoRouter.maybeOf(context);
      if (router != null && router.canPop()) {
        router.pop();
      }
    } on ApiError catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Playlist> async =
        ref.watch(libraryPlaylistProvider(widget.playlistId));

    final OfflineManifest? manifest =
        ref.watch(offlineManifestProvider).valueOrNull;
    final bool isMarked =
        manifest?.markedPlaylists.contains(widget.playlistId) ?? false;

    final SettingsValue? settings =
        ref.watch(settingsProvider).valueOrNull;
    final Playlist? loaded = async.valueOrNull;
    final bool canEdit = loaded != null &&
        settings != null &&
        loaded.owner != null &&
        loaded.owner == settings.navidromeUsername;

    final bool dirty =
        loaded != null && _isEditing && _hasPendingEdits(loaded);

    return PopScope<Object?>(
      // While edit mode is active, intercept system back so it exits the
      // editor (and surfaces a discard dialog if there are pending edits)
      // instead of popping the route. View mode pops normally.
      canPop: !_isEditing,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        if (dirty) {
          final bool ok = await _confirmDiscard();
          if (!ok) return;
        }
        if (mounted) _exitEdit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(async.maybeWhen<String>(
            data: (Playlist p) => p.name,
            orElse: () => 'Playlist',
          )),
          actions: <Widget>[
            if (_isEditing && loaded != null)
              IconButton(
                icon: const Icon(Icons.check),
                tooltip: 'Save changes',
                onPressed: _committing ? null : () => _onCommit(loaded),
              )
            else ...<Widget>[
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
                    n.unmarkPlaylist(widget.playlistId);
                  } else {
                    n.markPlaylist(widget.playlistId);
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
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit playlist',
                  onPressed: () => _enterEdit(loaded),
                ),
              if (canEdit)
                PopupMenuButton<_PlaylistAction>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'More',
                  onSelected: (_PlaylistAction a) async {
                    switch (a) {
                      case _PlaylistAction.rename:
                        await _onRename(loaded);
                      case _PlaylistAction.delete:
                        await _onDelete(loaded);
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
          ],
        ),
        body: async.when(
          loading: () => const SkeletonList(count: 6),
          error: (Object e, _) => Center(
            child: Text(e is ApiError ? e.message : 'Error: $e'),
          ),
          data: (Playlist p) =>
              _isEditing ? _buildEditBody(p) : _buildViewBody(ref, p),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // View mode body — same as M3.
  // -----------------------------------------------------------------
  Widget _buildViewBody(WidgetRef ref, Playlist playlist) {
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
          trailing: SongRowActions(
            song: s,
            trailingStatus:
                _buildSongTrailing(isCurrent, offline, containerMarked),
          ),
          onTap: () => playAllSongsFromSubsonic(
            ref,
            context,
            playlist.entry,
            startIndex: idx,
          ),
          onLongPress: () => AddToPlaylistSheet.show(
            context: context,
            songIds: <String>[s.id],
            findSimilarSeed: seedForSong(s),
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

  // -----------------------------------------------------------------
  // Edit mode body — header + ReorderableListView with delete + drag.
  // -----------------------------------------------------------------
  Widget _buildEditBody(Playlist playlist) {
    if (_editOrder.isEmpty) {
      return Column(
        children: <Widget>[
          _PlaylistHeader(playlist: playlist),
          const Expanded(
            child: Center(child: Text('No tracks to edit.')),
          ),
        ],
      );
    }
    return Column(
      children: <Widget>[
        _PlaylistHeader(playlist: playlist),
        Expanded(
          child: ReorderableListView.builder(
            itemCount: _editOrder.length,
            onReorderItem: (int oldIndex, int newIndex) {
              // onReorderItem auto-corrects the post-removal newIndex so
              // we don't need the historical `if (newIndex > oldIndex)
              // newIndex -= 1;` line that onReorder required.
              setState(() {
                final Song item = _editOrder.removeAt(oldIndex);
                _editOrder.insert(newIndex, item);
              });
            },
            itemBuilder: (BuildContext c, int i) {
              final Song s = _editOrder[i];
              final bool removed = _removedIds.contains(s.id);
              return ListTile(
                key: ValueKey<String>(s.id),
                leading: IconButton(
                  icon: Icon(
                    removed
                        ? Icons.add_circle_outline
                        : Icons.delete_outline,
                  ),
                  tooltip: removed ? 'Keep song' : 'Remove song',
                  onPressed: () => setState(() {
                    if (removed) {
                      _removedIds.remove(s.id);
                    } else {
                      _removedIds.add(s.id);
                    }
                  }),
                ),
                title: Text(
                  s.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: removed
                      ? const TextStyle(
                          decoration: TextDecoration.lineThrough,
                        )
                      : null,
                ),
                subtitle: Text(
                  s.artist ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: removed
                      ? const TextStyle(
                          decoration: TextDecoration.lineThrough,
                        )
                      : null,
                ),
                trailing: ReorderableDragStartListener(
                  index: i,
                  child: const Icon(Icons.drag_handle),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

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
