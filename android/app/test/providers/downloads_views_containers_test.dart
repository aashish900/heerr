import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/album.dart';
import 'package:heerr/models/subsonic/playlist.dart';
import 'package:heerr/offline/offline_manifest.dart';
import 'package:heerr/providers/downloaded_songs.dart';
import 'package:heerr/providers/downloads_filters.dart';
import 'package:heerr/providers/downloads_views.dart';
import 'package:heerr/providers/library/library_album.dart';
import 'package:heerr/providers/library/library_playlist.dart';

// DL6: sortedDownloadedAlbumsProvider / sortedDownloadedPlaylistsProvider —
// resolve ids to full metadata via the existing cache-aware providers, then
// reuse Library's sortAlbums/sortPlaylists rather than re-deriving sort
// logic (D3/D5 groundwork).

class _ToggledAlphaAlbums extends DownloadsAlbumSortNotifier {
  @override
  DownloadsContainerSort build() => DownloadsContainerSort.alphabetical;
}

class _ToggledAlphaPlaylists extends DownloadsPlaylistSortNotifier {
  @override
  DownloadsContainerSort build() => DownloadsContainerSort.alphabetical;
}

void main() {
  test('sortedDownloadedAlbumsProvider resolves ids and sorts alphabetically',
      () async {
    final ProviderContainer c = ProviderContainer(
      overrides: <Override>[
        downloadedAlbumIdsProvider.overrideWith((_) async => <String>['1', '2']),
        libraryAlbumProvider('1').overrideWith(
          (_) async => const Album(id: '1', name: 'Zebra'),
        ),
        libraryAlbumProvider('2').overrideWith(
          (_) async => const Album(id: '2', name: 'Alpha'),
        ),
        downloadsAlbumSortNotifierProvider.overrideWith(_ToggledAlphaAlbums.new),
      ],
    );
    addTearDown(c.dispose);

    final List<Album> out = await c.read(sortedDownloadedAlbumsProvider.future);

    expect(out.map((Album a) => a.name), <String>['Alpha', 'Zebra']);
  });

  test('sortedDownloadedAlbumsProvider tolerates a missing album cache',
      () async {
    final ProviderContainer c = ProviderContainer(
      overrides: <Override>[
        downloadedAlbumIdsProvider.overrideWith((_) async => <String>['1', '2']),
        libraryAlbumProvider('1').overrideWith(
          (_) async => const Album(id: '1', name: 'Only One'),
        ),
        libraryAlbumProvider('2').overrideWith(
          (_) async => throw Exception('cache miss'),
        ),
      ],
    );
    addTearDown(c.dispose);

    final List<Album> out = await c.read(sortedDownloadedAlbumsProvider.future);

    expect(out.map((Album a) => a.id), <String>['1']);
  });

  test('sortedDownloadedPlaylistsProvider resolves marked ids and sorts', () async {
    final ProviderContainer c = ProviderContainer(
      overrides: <Override>[
        offlineManifestProvider.overrideWith(
          (_) async => const OfflineManifest(markedPlaylists: <String>{'p1', 'p2'}),
        ),
        libraryPlaylistProvider('p1').overrideWith(
          (_) async => const Playlist(id: 'p1', name: 'Zeta'),
        ),
        libraryPlaylistProvider('p2').overrideWith(
          (_) async => const Playlist(id: 'p2', name: 'Beta'),
        ),
        downloadsPlaylistSortNotifierProvider.overrideWith(_ToggledAlphaPlaylists.new),
      ],
    );
    addTearDown(c.dispose);

    final List<Playlist> out = await c.read(sortedDownloadedPlaylistsProvider.future);

    expect(out.map((Playlist p) => p.name), <String>['Beta', 'Zeta']);
  });
}
