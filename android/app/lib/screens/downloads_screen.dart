import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/subsonic/album.dart';
import '../models/subsonic/playlist.dart';
import '../models/subsonic/song.dart';
import '../offline/offline_manifest.dart';
import '../player/playback_actions.dart';
import '../providers/downloaded_songs.dart';
import '../providers/library/library_album.dart';
import '../providers/library/library_playlist.dart';
import '../router.dart';
import '../widgets/library_cover_art.dart';
import '../widgets/library_result_tile.dart';

/// Browse-and-play surface for everything that has been downloaded for
/// offline use. Three top-tabs:
/// - **Albums** — every album in `OfflineManifest.markedAlbums`.
/// - **Playlists** — every playlist in `OfflineManifest.markedPlaylists`.
/// - **Songs** — flat list of every song whose manifest entry is `ready`,
///   resolved through the marked album / playlist metadata.
///
/// Every metadata fetch goes through the existing cache-aware library
/// providers (L5) so this screen works fully offline.
class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const <Widget>[
            Tab(text: 'Albums'),
            Tab(text: 'Playlists'),
            Tab(text: 'Songs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const <Widget>[
          _AlbumsTab(),
          _PlaylistsTab(),
          _SongsTab(),
        ],
      ),
    );
  }
}

class _AlbumsTab extends ConsumerWidget {
  const _AlbumsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<OfflineManifest> manifestAsync =
        ref.watch(offlineManifestProvider);
    return manifestAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, _) => _ErrorView(message: 'Manifest error: $e'),
      data: (OfflineManifest m) {
        final List<String> ids = m.markedAlbums.toList()..sort();
        if (ids.isEmpty) {
          return const _EmptyView(
            icon: Icons.album_outlined,
            message: 'No albums marked for offline.\n'
                'Mark an album from Library, or enable\n'
                '"Sync entire library" in Settings.',
          );
        }
        return ListView.builder(
          itemCount: ids.length,
          itemBuilder: (BuildContext c, int i) =>
              _AlbumRow(albumId: ids[i]),
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
    final AsyncValue<Album> albumAsync =
        ref.watch(libraryAlbumProvider(albumId));
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
        onTap: () => context.go(Routes.libraryAlbum(album.id)),
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
    final AsyncValue<OfflineManifest> manifestAsync =
        ref.watch(offlineManifestProvider);
    return manifestAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, _) => _ErrorView(message: 'Manifest error: $e'),
      data: (OfflineManifest m) {
        final List<String> ids = m.markedPlaylists.toList()..sort();
        if (ids.isEmpty) {
          return const _EmptyView(
            icon: Icons.queue_music_outlined,
            message: 'No playlists marked for offline.\n'
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
    final AsyncValue<Playlist> async =
        ref.watch(libraryPlaylistProvider(playlistId));
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
        onTap: () => context.go(Routes.libraryPlaylist(p.id)),
        trailingPlay: true,
        onPlay: () => playPlaylistFromSubsonic(ref, context, p.id),
      ),
    );
  }
}

class _SongsTab extends ConsumerWidget {
  const _SongsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Song>> async =
        ref.watch(downloadedSongsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, _) => _ErrorView(message: 'Songs error: $e'),
      data: (List<Song> songs) {
        if (songs.isEmpty) {
          return const _EmptyView(
            icon: Icons.music_off_outlined,
            message: 'No downloaded songs yet.\n'
                'Mark an album or playlist for offline,\n'
                'then wait for sync to complete.',
          );
        }
        return ListView.builder(
          itemCount: songs.length,
          itemBuilder: (BuildContext c, int i) {
            final Song s = songs[i];
            final String subtitle = <String?>[s.artist, s.album]
                .where((String? v) => v != null && v.isNotEmpty)
                .join(' • ');
            return ListTile(
              leading: LibraryCoverArt(coverArtId: s.coverArt),
              title: Text(s.title),
              subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
              onTap: () => playSongFromSubsonic(ref, context, s),
            );
          },
        );
      },
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
            Icon(icon, size: 64, color: cs.onSurfaceVariant),
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
