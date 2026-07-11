import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/album.dart';
import 'package:heerr/models/subsonic/artist.dart';
import 'package:heerr/models/subsonic/artist_index.dart';
import 'package:heerr/models/subsonic/playlist.dart';
import 'package:heerr/providers/library/library_albums.dart';
import 'package:heerr/providers/library/library_artists.dart';
import 'package:heerr/providers/library/library_playlists.dart';
import 'package:heerr/providers/profiles/profile_stats.dart';

void main() {
  test('sums playlists / songs / albums / artists from the library providers',
      () async {
    final ProviderContainer container = ProviderContainer(overrides: <Override>[
      libraryPlaylistsProvider.overrideWith(
        (LibraryPlaylistsRef ref) async => <Playlist>[
          const Playlist(id: '1', name: 'A'),
          const Playlist(id: '2', name: 'B'),
        ],
      ),
      libraryAlbumsProvider.overrideWith(
        (LibraryAlbumsRef ref) async => <Album>[
          const Album(id: '1', name: 'Al1', songCount: 10),
          const Album(id: '2', name: 'Al2', songCount: 5),
          const Album(id: '3', name: 'Al3'), // null songCount → contributes 0
        ],
      ),
      libraryArtistsProvider.overrideWith(
        (LibraryArtistsRef ref) async => <ArtistIndex>[
          const ArtistIndex(name: 'A', artist: <Artist>[
            Artist(id: '1', name: 'Artist One'),
            Artist(id: '2', name: 'Artist Two'),
          ]),
          const ArtistIndex(name: 'B', artist: <Artist>[
            Artist(id: '3', name: 'Artist Three'),
          ]),
        ],
      ),
    ]);
    addTearDown(container.dispose);

    final ProfileStats stats = await container.read(profileStatsProvider.future);

    expect(stats.playlists, 2);
    expect(stats.songs, 15);
    expect(stats.albums, 3);
    expect(stats.artists, 3);
  });

  group('formatStatCount', () {
    test('under 1000 renders as-is', () {
      expect(formatStatCount(0), '0');
      expect(formatStatCount(999), '999');
    });

    test('thousands render with one decimal + K, trailing .0 dropped', () {
      expect(formatStatCount(1000), '1K');
      expect(formatStatCount(1234), '1.2K');
      expect(formatStatCount(999999), '1000K');
    });

    test('millions render with one decimal + M', () {
      expect(formatStatCount(1000000), '1M');
      expect(formatStatCount(1500000), '1.5M');
    });
  });
}
