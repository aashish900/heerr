part of 'downloads_screen.dart';

/// Browse-and-play surface for everything that has been downloaded for
/// offline use. Three tabs (D3: Songs first — the primary intent of this
/// screen):
/// - **Songs** — flat list of every song whose manifest entry is `ready`,
///   resolved through the marked album / playlist metadata.
/// - **Albums** — every album in `OfflineManifest.markedAlbums`.
/// - **Playlists** — every playlist in `OfflineManifest.markedPlaylists`.
///
/// Every metadata fetch goes through the existing cache-aware library
/// providers (L5) so this screen works fully offline.

class _SongsTab extends ConsumerWidget {
  const _SongsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<DownloadedSongRow>> async =
        ref.watch(downloadedSongsViewProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, _) => _ErrorView(message: 'Songs error: $e'),
      data: (List<DownloadedSongRow> rows) {
        if (rows.isEmpty) {
          return const _TabEmptyWithStorage(
            icon: Icons.music_off_outlined,
            message:
                'No downloaded songs yet.\n'
                'Mark an album or playlist for offline,\n'
                'then wait for sync to complete.',
          );
        }
        return ListView.builder(
          itemCount: rows.length + 1,
          itemBuilder: (BuildContext c, int i) => i == rows.length
              ? const StorageCard()
              : _SongRow(row: rows[i]),
        );
      },
    );
  }
}

/// DL6: metadata line under the title — "Lossless • Yesterday • 24 MB"
/// (D7: Lossless covers `kLosslessSuffixes`, not just flac). Skips any
/// piece the manifest entry doesn't carry rather than showing a blank.
class _SongRow extends ConsumerWidget {
  const _SongRow({required this.row});
  final DownloadedSongRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Song s = row.song;
    final OfflineSongEntry e = row.entry;
    final List<String> parts = <String>[
      <String?>[s.artist, s.album]
          .where((String? v) => v != null && v.isNotEmpty)
          .join(' • '),
    ].where((String v) => v.isNotEmpty).toList();

    final List<String> metaParts = <String>[];
    final String? suffix = e.suffix;
    if (suffix != null && suffix.isNotEmpty) {
      metaParts.add(
        kLosslessSuffixes.contains(suffix.toLowerCase())
            ? 'Lossless'
            : suffix.toUpperCase(),
      );
    }
    final DateTime? at = e.downloadedAt;
    if (at != null) metaParts.add(_dayLabel(at));
    final int? size = e.size;
    if (size != null) metaParts.add(_humanBytes(size));
    if (metaParts.isNotEmpty) parts.add(metaParts.join(' • '));

    return ListTile(
      leading: LibraryCoverArt(coverArtId: s.coverArt),
      title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: parts.isEmpty
          ? null
          : Text(parts.join('\n'), maxLines: 2, overflow: TextOverflow.ellipsis),
      isThreeLine: parts.length > 1,
      trailing: IconButton(
        key: const Key('downloads-song-kebab'),
        icon: const Icon(Icons.more_vert),
        tooltip: 'More',
        onPressed: () => _showDeleteOptions(context, ref, s),
      ),
      onTap: () => playSongFromSubsonic(ref, context, s),
      onLongPress: () => _showDeleteOptions(context, ref, s),
    );
  }
}

String _dayLabel(DateTime at) {
  final DateTime now = DateTime.now();
  final DateTime d = DateTime(at.year, at.month, at.day);
  final DateTime today = DateTime(now.year, now.month, now.day);
  final int diff = today.difference(d).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${at.month}/${at.day}/${at.year}';
}

String _humanBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

class _AlbumsTab extends ConsumerWidget {
  const _AlbumsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Album>> async = ref.watch(sortedDownloadedAlbumsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, _) => _ErrorView(message: 'Downloads error: $e'),
      data: (List<Album> albums) {
        if (albums.isEmpty) {
          return const _TabEmptyWithStorage(
            icon: Icons.album_outlined,
            message:
                'No albums marked for offline.\n'
                'Mark an album or artist from Library, or enable\n'
                '"Sync entire library" in Settings.',
          );
        }
        return ListView.builder(
          itemCount: albums.length + 1,
          itemBuilder: (BuildContext c, int i) => i == albums.length
              ? const StorageCard()
              : _AlbumRow(album: albums[i]),
        );
      },
    );
  }
}

class _AlbumRow extends ConsumerWidget {
  const _AlbumRow({required this.album});
  final Album album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OfflineManifest? manifest = ref.watch(offlineManifestProvider).valueOrNull;
    final String subtitle = _containerSubtitle(
      primary: album.artist,
      songs: album.song,
      totalHint: album.songCount,
      manifest: manifest,
    );
    return LibraryResultTile(
      title: album.name,
      subtitle: subtitle,
      coverArtId: album.coverArt,
      onTap: () => context.push(Routes.libraryAlbum(album.id)),
      trailingPlay: true,
      onPlay: () => playAlbumFromSubsonic(ref, context, album.id),
    );
  }
}

class _PlaylistsTab extends ConsumerWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Playlist>> async =
        ref.watch(sortedDownloadedPlaylistsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, _) => _ErrorView(message: 'Manifest error: $e'),
      data: (List<Playlist> playlists) {
        if (playlists.isEmpty) {
          return const _TabEmptyWithStorage(
            icon: Icons.queue_music_outlined,
            message:
                'No playlists marked for offline.\n'
                'Mark a playlist from Library to download it.',
          );
        }
        return ListView.builder(
          itemCount: playlists.length + 1,
          itemBuilder: (BuildContext c, int i) => i == playlists.length
              ? const StorageCard()
              : _PlaylistRow(playlist: playlists[i]),
        );
      },
    );
  }
}

class _PlaylistRow extends ConsumerWidget {
  const _PlaylistRow({required this.playlist});
  final Playlist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OfflineManifest? manifest = ref.watch(offlineManifestProvider).valueOrNull;
    final String subtitle = _containerSubtitle(
      primary: playlist.owner == null ? null : 'by ${playlist.owner}',
      songs: playlist.entry,
      totalHint: playlist.songCount,
      manifest: manifest,
    );
    return LibraryResultTile(
      title: playlist.name,
      subtitle: subtitle,
      coverArtId: playlist.coverArt,
      onTap: () => context.push(Routes.libraryPlaylist(playlist.id)),
      trailingPlay: true,
      onPlay: () => playPlaylistFromSubsonic(ref, context, playlist.id),
    );
  }
}

/// DL6: "N songs ready of M" sub-line, cheap because the album/playlist
/// fetch already carries its song list — no extra provider needed. Falls
/// back to just [primary] when the manifest hasn't loaded yet.
String _containerSubtitle({
  required String? primary,
  required List<Song> songs,
  required int? totalHint,
  required OfflineManifest? manifest,
}) {
  final List<String> parts = <String>[if (primary != null && primary.isNotEmpty) primary];
  if (manifest != null && songs.isNotEmpty) {
    final int ready = songs
        .where((Song s) => manifest.songs[s.id]?.state == OfflineSongState.ready)
        .length;
    final int total = totalHint ?? songs.length;
    parts.add('$ready of $total songs ready');
  }
  return parts.join(' • ');
}

/// W1 (#41): long-press on a downloaded song offers three delete targets.
/// "Server" and "Both" are disabled when the song carries no Subsonic `path`
/// (nothing to identify the file by on the backend).
Future<void> _showDeleteOptions(
  BuildContext context,
  WidgetRef ref,
  Song song,
) {
  final bool canDeleteFromServer =
      song.path != null && song.path!.isNotEmpty;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetCtx) {
      final ColorScheme cs = Theme.of(sheetCtx).colorScheme;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Delete "${song.title}"',
                style: Theme.of(sheetCtx).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ListTile(
              key: const Key('delete-song-device'),
              leading: const Icon(Icons.phonelink_erase_outlined),
              title: const Text('Delete from device'),
              subtitle: const Text('Keeps the song in the server library'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _confirmDelete(context, ref, song,
                    fromDevice: true, fromServer: false);
              },
            ),
            ListTile(
              key: const Key('delete-song-server'),
              enabled: canDeleteFromServer,
              leading: Icon(Icons.cloud_off_outlined, color: cs.error),
              title: Text('Delete from server',
                  style: TextStyle(color: cs.error)),
              subtitle:
                  const Text('Removes the file from the Navidrome library'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _confirmDelete(context, ref, song,
                    fromDevice: false, fromServer: true);
              },
            ),
            ListTile(
              key: const Key('delete-song-both'),
              enabled: canDeleteFromServer,
              leading: Icon(Icons.delete_forever_outlined, color: cs.error),
              title: Text('Delete from both', style: TextStyle(color: cs.error)),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _confirmDelete(context, ref, song,
                    fromDevice: true, fromServer: true);
              },
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  Song song, {
  required bool fromDevice,
  required bool fromServer,
}) async {
  if (!context.mounted) return;
  final String title = fromServer
      ? (fromDevice ? 'Delete from device and server?' : 'Delete from server?')
      : 'Delete from device?';
  final String body = fromServer
      ? '"${song.title}" will be permanently deleted from the Navidrome '
          'library for every user${fromDevice ? ' and removed from this '
          'device' : ''}. This cannot be undone.'
      : '"${song.title}" will be removed from your device. '
          'It stays in your Navidrome library and will re-download '
          'on the next sync if the album is still marked offline.';
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
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
  if (confirmed != true || !context.mounted) return;

  if (fromDevice) {
    await ref.read(offlineMarkerProvider.notifier).deleteSongLocally(song.id);
  }
  if (fromServer) {
    try {
      await ref.read(libraryDeleteProvider.notifier).deleteFromServer(song);
    } on ApiError catch (e) {
      if (!context.mounted) return;
      showApiError(context, e);
      return;
    }
  }
  if (!context.mounted) return;
  final String where = fromServer
      ? (fromDevice
          ? 'device and server — library updates after the next Navidrome scan'
          : 'server — library updates after the next Navidrome scan')
      : 'device';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      duration: kSnackBarDuration,
      content: Text('Deleted "${song.title}" from $where'),
    ));
}

/// DL7: empty-tab state with the storage card pinned below it — usage is
/// orthogonal to whether *this* tab's data list is empty.
class _TabEmptyWithStorage extends StatelessWidget {
  const _TabEmptyWithStorage({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(child: _EmptyView(icon: icon, message: message)),
        const StorageCard(),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            GradientIcon(child: Icon(icon, size: 64)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
