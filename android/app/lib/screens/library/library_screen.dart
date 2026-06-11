import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_error.dart';
import '../../models/subsonic/album.dart';
import '../../models/subsonic/artist.dart';
import '../../models/subsonic/artist_index.dart';
import '../../models/subsonic/playlist.dart';
import '../../providers/library/library_albums.dart';
import '../../providers/library/library_artists.dart';
import '../../providers/library/library_playlists.dart';
import '../../router.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/library_result_tile.dart';
import '../../widgets/skeleton.dart';

/// Library tab — a `TabBar` of three sub-tabs (Artists / Albums / Playlists),
/// each driven by its own provider. Search is added at I2 (combined library
/// + YouTube Music). At I1 there is no search field; just browse.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Library'),
          bottom: const TabBar(
            tabs: <Tab>[
              Tab(text: 'Artists'),
              Tab(text: 'Albums'),
              Tab(text: 'Playlists'),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[
            _ArtistsTab(),
            _AlbumsTab(),
            _PlaylistsTab(),
          ],
        ),
      ),
    );
  }
}

class _ArtistsTab extends ConsumerWidget {
  const _ArtistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ArtistIndex>> async =
        ref.watch(libraryArtistsProvider);
    return async.when(
      loading: () => const SkeletonList(count: 6),
      error: (Object e, _) => Center(
        child: Text(e is ApiError ? e.message : 'Error: $e'),
      ),
      data: (List<ArtistIndex> indices) {
        if (indices.isEmpty || indices.every((ArtistIndex i) => i.artist.isEmpty)) {
          return const EmptyState(
            icon: Icons.person_outline,
            title: 'No artists yet',
            subtitle:
                'Library is empty. Download something via the queue or search.',
          );
        }
        return ListView(
          children: <Widget>[
            for (final ArtistIndex group in indices) ...<Widget>[
              if (group.artist.isNotEmpty) _SectionHeader(label: group.name),
              for (final Artist a in group.artist)
                LibraryResultTile(
                  title: a.name,
                  subtitle: a.albumCount == null
                      ? null
                      : '${a.albumCount} albums',
                  coverArtId: a.coverArt,
                  onTap: () => context.push(Routes.libraryArtist(a.id)),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _AlbumsTab extends ConsumerWidget {
  const _AlbumsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Album>> async = ref.watch(libraryAlbumsProvider);
    return async.when(
      loading: () => const SkeletonList(count: 6),
      error: (Object e, _) => Center(
        child: Text(e is ApiError ? e.message : 'Error: $e'),
      ),
      data: (List<Album> albums) {
        if (albums.isEmpty) {
          return const EmptyState(
            icon: Icons.album_outlined,
            title: 'No albums yet',
            subtitle:
                'Library is empty. Download something via the queue or search.',
          );
        }
        return ListView.builder(
          itemCount: albums.length,
          itemBuilder: (BuildContext c, int i) {
            final Album a = albums[i];
            return LibraryResultTile(
              title: a.name,
              subtitle: a.artist,
              coverArtId: a.coverArt,
              trailingPlay: true,
              onTap: () => context.push(Routes.libraryAlbum(a.id)),
              // onPlay is wired at J2 — placeholder no-op for I1.
            );
          },
        );
      },
    );
  }
}

class _PlaylistsTab extends ConsumerWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Playlist>> async =
        ref.watch(libraryPlaylistsProvider);
    return async.when(
      loading: () => const SkeletonList(count: 6),
      error: (Object e, _) => Center(
        child: Text(e is ApiError ? e.message : 'Error: $e'),
      ),
      data: (List<Playlist> playlists) {
        if (playlists.isEmpty) {
          return const EmptyState(
            icon: Icons.queue_music_outlined,
            title: 'No playlists yet',
            subtitle: 'Create a playlist on Navidrome to see it here.',
          );
        }
        return ListView.builder(
          itemCount: playlists.length,
          itemBuilder: (BuildContext c, int i) {
            final Playlist p = playlists[i];
            return LibraryResultTile(
              title: p.name,
              subtitle: p.songCount == null ? null : '${p.songCount} songs',
              coverArtId: p.coverArt,
              trailingPlay: true,
              onTap: () => context.push(Routes.libraryPlaylist(p.id)),
            );
          },
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
