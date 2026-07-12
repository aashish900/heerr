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
    final AsyncValue<List<Song>> async = ref.watch(downloadedSongsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, _) => _ErrorView(message: 'Songs error: $e'),
      data: (List<Song> songs) {
        if (songs.isEmpty) {
          return const _EmptyView(
            icon: Icons.music_off_outlined,
            message:
                'No downloaded songs yet.\n'
                'Mark an album or playlist for offline,\n'
                'then wait for sync to complete.',
          );
        }
        return ListView.builder(
          itemCount: songs.length,
          itemBuilder: (BuildContext c, int i) {
            final Song s = songs[i];
            final String subtitle = <String?>[
              s.artist,
              s.album,
            ].where((String? v) => v != null && v.isNotEmpty).join(' • ');
            return ListTile(
              leading: LibraryCoverArt(coverArtId: s.coverArt),
              title: Text(s.title),
              subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
              onTap: () => playSongFromSubsonic(ref, context, s),
              onLongPress: () => _showDeleteOptions(context, ref, s),
            );
          },
        );
      },
    );
  }
}

class _AlbumsTab extends ConsumerWidget {
  const _AlbumsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use the union provider — markedAlbums plus every album reached
    // through a markedArtists expansion. Without this, marking an
    // artist would download the songs but the Albums / Songs tabs
    // would stay empty until the user also individually marked each
    // album under the artist.
    final AsyncValue<List<String>> idsAsync = ref.watch(
      downloadedAlbumIdsProvider,
    );
    return idsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, _) => _ErrorView(message: 'Downloads error: $e'),
      data: (List<String> ids) {
        if (ids.isEmpty) {
          return const _EmptyView(
            icon: Icons.album_outlined,
            message:
                'No albums marked for offline.\n'
                'Mark an album or artist from Library, or enable\n'
                '"Sync entire library" in Settings.',
          );
        }
        return ListView.builder(
          itemCount: ids.length,
          itemBuilder: (BuildContext c, int i) => _AlbumRow(albumId: ids[i]),
        );
      },
    );
  }
}

class _AlbumRow extends ConsumerWidget {
  const _AlbumRow({required this.albumId});
  final String albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Album> albumAsync = ref.watch(
      libraryAlbumProvider(albumId),
    );
    return albumAsync.when(
      loading: () => const ListTile(
        leading: SizedBox(
          width: 56,
          height: 56,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        title: Text('Loading…'),
      ),
      error: (Object e, _) => ListTile(
        leading: const Icon(Icons.error_outline),
        title: Text('Album $albumId'),
        subtitle: Text('Couldn\'t load: $e'),
      ),
      data: (Album album) => LibraryResultTile(
        title: album.name,
        subtitle: album.artist,
        coverArtId: album.coverArt,
        onTap: () => context.push(Routes.libraryAlbum(album.id)),
        trailingPlay: true,
        onPlay: () => playAlbumFromSubsonic(ref, context, album.id),
      ),
    );
  }
}

class _PlaylistsTab extends ConsumerWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<OfflineManifest> manifestAsync = ref.watch(
      offlineManifestProvider,
    );
    return manifestAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, _) => _ErrorView(message: 'Manifest error: $e'),
      data: (OfflineManifest m) {
        final List<String> ids = m.markedPlaylists.toList()..sort();
        if (ids.isEmpty) {
          return const _EmptyView(
            icon: Icons.queue_music_outlined,
            message:
                'No playlists marked for offline.\n'
                'Mark a playlist from Library to download it.',
          );
        }
        return ListView.builder(
          itemCount: ids.length,
          itemBuilder: (BuildContext c, int i) =>
              _PlaylistRow(playlistId: ids[i]),
        );
      },
    );
  }
}

class _PlaylistRow extends ConsumerWidget {
  const _PlaylistRow({required this.playlistId});
  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Playlist> async = ref.watch(
      libraryPlaylistProvider(playlistId),
    );
    return async.when(
      loading: () => const ListTile(
        leading: SizedBox(
          width: 56,
          height: 56,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        title: Text('Loading…'),
      ),
      error: (Object e, _) => ListTile(
        leading: const Icon(Icons.error_outline),
        title: Text('Playlist $playlistId'),
        subtitle: Text('Couldn\'t load: $e'),
      ),
      data: (Playlist p) => LibraryResultTile(
        title: p.name,
        subtitle: p.owner,
        coverArtId: p.coverArt,
        onTap: () => context.push(Routes.libraryPlaylist(p.id)),
        trailingPlay: true,
        onPlay: () => playPlaylistFromSubsonic(ref, context, p.id),
      ),
    );
  }
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
