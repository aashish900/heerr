import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/album.dart';
import 'package:heerr/models/subsonic/artist.dart';
import 'package:heerr/models/subsonic/artist_index.dart';
import 'package:heerr/models/subsonic/playlist.dart';
import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/player/browse_ids.dart';
import 'package:heerr/player/browse_tree.dart';
import 'package:heerr/providers/downloaded_songs.dart';
import 'package:heerr/providers/home/home_providers.dart';
import 'package:heerr/providers/library/favourites.dart';
import 'package:heerr/providers/library/library_album.dart';
import 'package:heerr/providers/library/library_albums.dart';
import 'package:heerr/providers/library/library_artist.dart';
import 'package:heerr/providers/library/library_artists.dart';
import 'package:heerr/providers/library/library_playlist.dart';
import 'package:heerr/providers/library/library_playlists.dart';
import 'package:heerr/providers/profiles/active_profile.dart';

import '../support/cred_test_support.dart';

const _song1 = Song(
  id: 's1',
  title: 'One',
  artist: 'Ann',
  album: 'Alpha',
  coverArt: 'c1',
  duration: 60,
);
const _song2 = Song(id: 's2', title: 'Two', artist: 'Ann', album: 'Alpha');

void main() {
  ProviderContainer make({
    bool withProfile = true,
    List<Override> more = const [],
  }) {
    final c = ProviderContainer(
      overrides: [
        activeProfileProvider.overrideWithValue(
          withProfile ? testProfile() : null,
        ),
        ...more,
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<List<String>> ids(ProviderContainer c, BrowseId parent) async => [
    for (final i in await browseChildren(c, parent)) i.id,
  ];

  test(
    'root lists the six tabs, browsable, with ids the parser accepts',
    () async {
      final items = await browseChildren(make(), BrowseId.root);
      expect(items.map((i) => i.id), [
        'recents',
        'favourites',
        'playlists',
        'albums',
        'artists',
        'downloaded',
      ]);
      expect(items.every((i) => i.playable == false), isTrue);
      expect(items.every((i) => BrowseId.tryParse(i.id) != null), isTrue);
    },
  );

  test('root works with no active profile (no creds needed)', () async {
    final items = await browseChildren(make(withProfile: false), BrowseId.root);
    expect(items, hasLength(6));
  });

  test('albums/artists tabs ask for a grid, others do not', () async {
    final items = await browseChildren(make(), BrowseId.root);
    const key = 'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT';
    final hints = {for (final i in items) i.id: i.extras?[key]};
    expect(hints['albums'], 2);
    expect(hints['artists'], 2);
    expect(hints['playlists'], isNull);
  });

  test('albums tab: browsable album items with sized, authed art', () async {
    final c = make(
      more: [
        libraryAlbumsProvider.overrideWith(
          (ref) async => [
            const Album(id: 'a1', name: 'Alpha', artist: 'Ann', coverArt: 'c1'),
            const Album(id: 'a2', name: 'Beta'),
          ],
        ),
      ],
    );
    final items = await browseChildren(c, const BrowseId(BrowseKind.albums));
    expect(items.map((i) => i.id), ['album:a1', 'album:a2']);
    expect(items[0].title, 'Alpha');
    expect(items[0].artist, 'Ann');
    expect(items[0].playable, isFalse);
    final art = items[0].artUri!;
    expect(art.path, '/rest/getCoverArt.view');
    expect(art.queryParameters['id'], 'c1');
    expect(art.queryParameters['size'], '300');
    expect(art.queryParameters['u'], 'me');
    expect(art.queryParameters.containsKey('t'), isTrue);
    expect(items[1].artUri, isNull, reason: 'no coverArt id -> no art');
  });

  test('albums tab is capped', () async {
    final c = make(
      more: [
        libraryAlbumsProvider.overrideWith(
          (ref) async => [
            for (var i = 0; i < kMaxBrowseItems + 50; i++)
              Album(id: 'a$i', name: 'A$i'),
          ],
        ),
      ],
    );
    expect(
      await browseChildren(c, const BrowseId(BrowseKind.albums)),
      hasLength(kMaxBrowseItems),
    );
  });

  test('recents tab: recently played albums', () async {
    final c = make(
      more: [
        recentlyPlayedProvider.overrideWith(
          (ref) async => [const Album(id: 'r1', name: 'R')],
        ),
      ],
    );
    expect(await ids(c, const BrowseId(BrowseKind.recents)), ['album:r1']);
  });

  test('artists tab flattens the index', () async {
    final c = make(
      more: [
        libraryArtistsProvider.overrideWith(
          (ref) async => [
            const ArtistIndex(
              name: 'A',
              artist: [
                Artist(id: 'ar1', name: 'Ann'),
                Artist(id: 'ar2', name: 'Abe'),
              ],
            ),
            const ArtistIndex(
              name: 'B',
              artist: [Artist(id: 'ar3', name: 'Bo')],
            ),
          ],
        ),
      ],
    );
    expect(await ids(c, const BrowseId(BrowseKind.artists)), [
      'artist:ar1',
      'artist:ar2',
      'artist:ar3',
    ]);
  });

  test('playlists tab lists playlists as browsable items', () async {
    final c = make(
      more: [
        libraryPlaylistsProvider.overrideWith(
          (ref) async => [const Playlist(id: 'p1', name: 'Road')],
        ),
      ],
    );
    final items = await browseChildren(c, const BrowseId(BrowseKind.playlists));
    expect(items.single.id, 'playlist:p1');
    expect(items.single.playable, isFalse);
  });

  test('album node -> playable songs that remember the album', () async {
    final c = make(
      more: [
        libraryAlbumProvider('a1').overrideWith(
          (ref) async =>
              const Album(id: 'a1', name: 'Alpha', song: [_song1, _song2]),
        ),
      ],
    );
    final items = await browseChildren(
      c,
      const BrowseId(BrowseKind.album, 'a1'),
    );
    expect(items.map((i) => i.id), ['album:a1/song:s1', 'album:a1/song:s2']);
    expect(items.every((i) => i.playable == true), isTrue);
    expect(items[0].title, 'One');
    expect(items[0].duration, const Duration(seconds: 60));
    expect(items[0].extras?['subsonicId'], 's1');
  });

  test('artist node -> its albums', () async {
    final c = make(
      more: [
        libraryArtistProvider('ar1').overrideWith(
          (ref) async => const Artist(
            id: 'ar1',
            name: 'Ann',
            album: [Album(id: 'a1', name: 'Alpha')],
          ),
        ),
      ],
    );
    expect(await ids(c, const BrowseId(BrowseKind.artist, 'ar1')), [
      'album:a1',
    ]);
  });

  test('playlist node -> songs with playlist parent', () async {
    final c = make(
      more: [
        libraryPlaylistProvider('p1').overrideWith(
          (ref) async =>
              const Playlist(id: 'p1', name: 'Road', entry: [_song1]),
        ),
      ],
    );
    expect(await ids(c, const BrowseId(BrowseKind.playlist, 'p1')), [
      'playlist:p1/song:s1',
    ]);
  });

  test('favourites tab -> songs of the Favourites playlist', () async {
    final c = make(
      more: [
        libraryPlaylistsProvider.overrideWith(
          (ref) async => [
            const Playlist(id: 'f', name: kFavouritesPlaylistName, owner: 'me'),
            const Playlist(id: 'x', name: 'Other', owner: 'me'),
          ],
        ),
        libraryPlaylistProvider('f').overrideWith(
          (ref) async => const Playlist(
            id: 'f',
            name: kFavouritesPlaylistName,
            owner: 'me',
            entry: [_song2],
          ),
        ),
      ],
    );
    expect(await ids(c, const BrowseId(BrowseKind.favourites)), [
      'favourites/song:s2',
    ]);
  });

  test('favourites tab is empty when no Favourites playlist exists', () async {
    final c = make(
      more: [
        libraryPlaylistsProvider.overrideWith((ref) async => <Playlist>[]),
      ],
    );
    expect(await ids(c, const BrowseId(BrowseKind.favourites)), isEmpty);
  });

  test('downloaded tab -> downloaded songs, offline-safe', () async {
    final c = make(
      more: [
        downloadedSongsProvider.overrideWith((ref) async => [_song1]),
      ],
    );
    expect(await ids(c, const BrowseId(BrowseKind.downloaded)), [
      'downloaded/song:s1',
    ]);
  });

  test(
    'data tabs are empty without creds; song nodes have no children',
    () async {
      final c = make(withProfile: false);
      expect(await ids(c, const BrowseId(BrowseKind.albums)), isEmpty);
      expect(await ids(c, const BrowseId(BrowseKind.song, 's1')), isEmpty);
    },
  );
}
