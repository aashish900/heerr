import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_error.dart';
import '../../models/subsonic/album.dart';
import '../../models/subsonic/song.dart';
import '../../offline/offline_manifest.dart';
import '../../offline/offline_marker.dart';
import '../../player/playback_actions.dart';
import '../../player/player_provider.dart';
import '../../providers/library/library_album.dart';
import '../../theme.dart';
import '../../widgets/add_to_playlist_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/library_cover_art.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/song_row_actions.dart';

/// Album detail. Header with cover + name + artist + year above the song
/// list. Song row tap = play the album starting at that song. AppBar
/// "Play all" = play the album from the top.
class AlbumDetailScreen extends ConsumerWidget {
  const AlbumDetailScreen({required this.albumId, super.key});

  final String albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Album> async = ref.watch(libraryAlbumProvider(albumId));

    final OfflineManifest? manifest =
        ref.watch(offlineManifestProvider).valueOrNull;
    // Album AppBar lights up green when the album is marked directly OR
    // when its parent artist is marked. We can only know the artist id
    // once the album has loaded; before then `isMarked` is conservative
    // (just `markedAlbums`). Tapping the IconButton always toggles the
    // **album-level** mark — unmarking via the parent artist is done
    // from the artist screen, which matches "flow top-down".
    final String? artistId = async.valueOrNull?.artistId;
    final bool isMarked = (manifest?.markedAlbums.contains(albumId) ??
            false) ||
        (artistId != null &&
            (manifest?.markedArtists.contains(artistId) ?? false));

    return Scaffold(
      appBar: AppBar(
        title: Text(async.maybeWhen<String>(
          data: (Album a) => a.name,
          orElse: () => 'Album',
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
                n.unmarkAlbum(albumId);
              } else {
                n.markAlbum(albumId);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow_outlined),
            tooltip: 'Play all',
            onPressed: () {
              final Album? a = async.valueOrNull;
              if (a == null) return;
              playAllSongsFromSubsonic(ref, context, a.song);
            },
          ),
          if (async.valueOrNull != null)
            PopupMenuButton<_AlbumAction>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More',
              onSelected: (_AlbumAction a) {
                switch (a) {
                  case _AlbumAction.addAlbumToPlaylist:
                    final Album? album = async.valueOrNull;
                    if (album == null) return;
                    AddToPlaylistSheet.show(
                      context: context,
                      songIds: <String>[
                        for (final Song s in album.song) s.id,
                      ],
                    );
                }
              },
              itemBuilder: (BuildContext c) =>
                  const <PopupMenuEntry<_AlbumAction>>[
                PopupMenuItem<_AlbumAction>(
                  value: _AlbumAction.addAlbumToPlaylist,
                  child: Text('Add album to playlist…'),
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
        data: (Album a) => _Body(album: a),
      ),
    );
  }
}

enum _AlbumAction { addAlbumToPlaylist }

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
    final OfflineManifest? manifest =
        ref.watch(offlineManifestProvider).valueOrNull;
    // "Marked via container" — sync hasn't downloaded the song yet, but
    // the album or its parent artist is already marked. We surface that
    // as a soft scheduled badge so the user gets immediate top-down
    // visual feedback after marking the artist / album.
    final bool containerMarked =
        (manifest?.markedAlbums.contains(album.id) ?? false) ||
            (album.artistId != null &&
                (manifest?.markedArtists.contains(album.artistId!) ?? false));
    return ListView.builder(
      itemCount: album.song.length + 1,
      itemBuilder: (BuildContext c, int i) {
        if (i == 0) return _AlbumHeader(album: album);
        final int idx = i - 1;
        final Song s = album.song[idx];
        final bool isCurrent = s.id == currentSubsonicId;
        final OfflineSongEntry? offline = manifest?.songs[s.id];
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
          trailing: SongRowActions(
            song: s,
            trailingStatus:
                _buildSongTrailing(isCurrent, offline, containerMarked),
          ),
          onTap: () => playAllSongsFromSubsonic(
            ref,
            context,
            album.song,
            startIndex: idx,
          ),
          onLongPress: () => AddToPlaylistSheet.show(
            context: context,
            songIds: <String>[s.id],
          ),
        );
      },
    );
  }

  /// Per-song trailing affordance precedence:
  ///   isCurrent wins → playing indicator;
  ///   else offline state visible (ready/downloading/failed/queued);
  ///   else container-marked → soft scheduled badge;
  ///   else null.
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
        // Top-down propagation: container is marked, sync just hasn't
        // produced a manifest entry yet. Mirror the AppBar's outlined
        // download glyph so the user sees a consistent "will be
        // downloaded" signal from artist → album → song.
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
        return const Icon(
          Icons.schedule,
          size: 18,
        );
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
