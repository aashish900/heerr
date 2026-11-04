import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/album.dart';
import 'package:heerr/models/subsonic/artist.dart';
import 'package:heerr/models/subsonic/playlist.dart';
import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/offline/local_uri.dart';
import 'package:heerr/player/browse_ids.dart';
import 'package:heerr/player/browse_play.dart';
import 'package:heerr/providers/downloaded_songs.dart';
import 'package:heerr/providers/library/favourites.dart';
import 'package:heerr/providers/library/library_album.dart';
import 'package:heerr/providers/library/library_artist.dart';
import 'package:heerr/providers/library/library_playlist.dart';
import 'package:heerr/providers/library/library_playlists.dart';
import 'package:heerr/providers/profiles/active_profile.dart';

import '../support/cred_test_support.dart';

const _s1 = Song(id: 's1', title: 'One');
const _s2 = Song(id: 's2', title: 'Two');
const _s3 = Song(id: 's3', title: 'Three');

void main() {
  late List<MediaItem> played;
  late int? startedAt;

  Future<void> fakePlayAll(List<MediaItem> items, int start) async {
    played = items;
    startedAt = start;
  }

  setUp(() {
    played = <MediaItem>[];
    startedAt = null;
  });

  ProviderContainer make({
    bool withProfile = true,
    Map<String, String> localUris = const <String, String>{},
    List<Override> more = const [],
  }) {
    final c = ProviderContainer(
      overrides: [
        activeProfileProvider.overrideWithValue(
          withProfile ? testProfile() : null,
        ),
        for (final id in ['s1', 's2', 's3', 'gone'])
          localUriForProvider(id).overrideWith((ref) async => localUris[id]),
        ...more,
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> play(ProviderContainer c, String id) async {
    final parsed = BrowseId.tryParse(id)!;
    await playBrowseId(c, parsed, fakePlayAll);
  }

  List<String> songIds() => [
    for (final i in played) i.extras!['subsonicId'] as String,
  ];

  test('song in an album queues the whole album from that song', () async {
    final c = make(
      more: [
        libraryAlbumProvider('a1').overrideWith(
          (ref) async =>
              const Album(id: 'a1', name: 'A', song: [_s1, _s2, _s3]),
        ),
      ],
    );
    await play(c, 'album:a1/song:s2');
    expect(songIds(), ['s1', 's2', 's3']);
    expect(startedAt, 1);
    expect(played.first.id, contains('/rest/stream.view'));
    expect(played.first.id, contains('id=s1'));
  });

  test('song in a playlist queues the playlist from that song', () async {
    final c = make(
      more: [
        libraryPlaylistProvider('p1').overrideWith(
          (ref) async => const Playlist(id: 'p1', name: 'P', entry: [_s1, _s2]),
        ),
      ],
    );
    await play(c, 'playlist:p1/song:s2');
    expect(songIds(), ['s1', 's2']);
    expect(startedAt, 1);
  });

  test('song in favourites queues the favourites playlist', () async {
    final c = make(
      more: [
        libraryPlaylistsProvider.overrideWith(
          (ref) async => [
            const Playlist(id: 'f', name: kFavouritesPlaylistName, owner: 'me'),
          ],
        ),
        libraryPlaylistProvider('f').overrideWith(
          (ref) async => const Playlist(
            id: 'f',
            name: kFavouritesPlaylistName,
            owner: 'me',
            entry: [_s1, _s3],
          ),
        ),
      ],
    );
    await play(c, 'favourites/song:s3');
    expect(songIds(), ['s1', 's3']);
    expect(startedAt, 1);
  });

  test(
    'downloaded songs play from the local file, not the stream URL',
    () async {
      final c = make(
        localUris: {'s2': 'file:///data/heerr/s2.mp3'},
        more: [
          downloadedSongsProvider.overrideWith((ref) async => [_s1, _s2]),
        ],
      );
      await play(c, 'downloaded/song:s1');
      expect(played[0].id, contains('/rest/stream.view'));
      expect(played[1].id, 'file:///data/heerr/s2.mp3');
      expect(startedAt, 0);
    },
  );

  test(
    'a song that is no longer in its parent falls back to the start',
    () async {
      final c = make(
        more: [
          libraryAlbumProvider('a1').overrideWith(
            (ref) async => const Album(id: 'a1', name: 'A', song: [_s1, _s2]),
          ),
        ],
      );
      await play(c, 'album:a1/song:gone');
      expect(songIds(), ['s1', 's2']);
      expect(startedAt, 0);
    },
  );

  test('album container plays from the first song', () async {
    final c = make(
      more: [
        libraryAlbumProvider('a1').overrideWith(
          (ref) async => const Album(id: 'a1', name: 'A', song: [_s1, _s2]),
        ),
      ],
    );
    await play(c, 'album:a1');
    expect(songIds(), ['s1', 's2']);
    expect(startedAt, 0);
  });

  test('artist container plays every album in the artist order', () async {
    final c = make(
      more: [
        libraryArtistProvider('ar1').overrideWith(
          (ref) async => const Artist(
            id: 'ar1',
            name: 'X',
            album: [
              Album(id: 'a1', name: 'A'),
              Album(id: 'a2', name: 'B'),
            ],
          ),
        ),
        libraryAlbumProvider('a1').overrideWith(
          (ref) async => const Album(id: 'a1', name: 'A', song: [_s1]),
        ),
        libraryAlbumProvider('a2').overrideWith(
          (ref) async => const Album(id: 'a2', name: 'B', song: [_s2, _s3]),
        ),
      ],
    );
    await play(c, 'artist:ar1');
    expect(songIds(), ['s1', 's2', 's3']);
  });

  test('tabs, bare songs and missing creds start nothing', () async {
    final c = make();
    await play(c, 'albums');
    await play(c, 'root');
    await play(c, 'song:s1');
    expect(played, isEmpty);

    final noCreds = make(withProfile: false);
    await play(noCreds, 'album:a1/song:s1');
    expect(played, isEmpty);
  });
}
