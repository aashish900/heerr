import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/album.dart';
import 'package:heerr/models/subsonic/playlist.dart';
import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/providers/library/library_album.dart';
import 'package:heerr/providers/library/library_playlists.dart';
import 'package:heerr/providers/library/playlist_mutations.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/screens/library/album_detail_screen.dart';
import 'package:heerr/widgets/empty_state.dart';
import 'package:heerr/widgets/skeleton.dart';

class _NoopStorage implements SecureStorage {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

/// Records the song id list passed to addSongs / createPlaylist via the
/// M3 add-to-playlist sheet. Used by the album-detail extension tests
/// to assert long-press → single song and overflow → whole album.
class _StubPlaylistMutations extends PlaylistMutations {
  static List<String>? lastAddSongIds;
  static String? lastAddPlaylistId;

  static void reset() {
    lastAddSongIds = null;
    lastAddPlaylistId = null;
  }

  @override
  void build() {}

  @override
  Future<void> addSongs({
    required String playlistId,
    required List<String> songIds,
  }) async {
    lastAddPlaylistId = playlistId;
    lastAddSongIds = List<String>.from(songIds);
  }
}

Override _playlistsValue(AsyncValue<List<Playlist>> value) {
  return libraryPlaylistsProvider.overrideWith(
    (Ref<AsyncValue<List<Playlist>>> ref) {
      return value.when(
        data: (List<Playlist> v) => Future<List<Playlist>>.value(v),
        loading: () => Completer<List<Playlist>>().future,
        error: (Object e, StackTrace st) =>
            Future<List<Playlist>>.error(e, st),
      );
    },
  );
}

Override _albumValue(String id, AsyncValue<Album> value) {
  return libraryAlbumProvider(id).overrideWith(
    (Ref<AsyncValue<Album>> ref) {
      return value.when(
        data: (Album a) => Future<Album>.value(a),
        loading: () => Completer<Album>().future,
        error: (Object e, StackTrace st) => Future<Album>.error(e, st),
      );
    },
  );
}

Widget _wrap(String id, List<Override> overrides) {
  return ProviderScope(
    overrides: <Override>[
      secureStorageProvider.overrideWithValue(_NoopStorage()),
      ...overrides,
    ],
    child: MaterialApp(home: AlbumDetailScreen(albumId: id)),
  );
}

void main() {
  testWidgets('loading → SkeletonList', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap('al-1', <Override>[
      _albumValue('al-1', const AsyncLoading<Album>()),
    ]));
    await tester.pump();
    expect(find.byType(SkeletonList), findsOneWidget);
  });

  testWidgets('empty (no songs) → EmptyState "No songs"',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap('al-1', <Override>[
      _albumValue(
        'al-1',
        const AsyncData<Album>(Album(id: 'al-1', name: 'X')),
      ),
    ]));
    await tester.pumpAndSettle();
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No songs'), findsOneWidget);
  });

  testWidgets(
    'data → renders header + song list with track numbers and durations',
    (WidgetTester tester) async {
      const Album a = Album(
        id: 'al-1',
        name: 'Currents',
        artist: 'Tame Impala',
        year: 2015,
        song: <Song>[
          Song(id: 'so-1', title: 'Let It Happen', track: 1, duration: 467),
          Song(id: 'so-2', title: 'Nangs', track: 2, duration: 108),
        ],
      );
      await tester.pumpWidget(_wrap('al-1', <Override>[
        _albumValue('al-1', const AsyncData<Album>(a)),
      ]));
      await tester.pumpAndSettle();

      // Album name appears in AppBar AND in header — but Currents/Tame Impala
      // are present in only specific places.
      expect(find.text('Tame Impala'), findsOneWidget); // header
      expect(find.text('2015'), findsOneWidget); // header
      expect(find.text('Let It Happen'), findsOneWidget);
      expect(find.text('Nangs'), findsOneWidget);
      expect(find.text('7:47'), findsOneWidget); // 467s → 7:47
      expect(find.text('1:48'), findsOneWidget); // 108s → 1:48
    },
  );

  testWidgets('error → renders error message',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap('al-1', <Override>[
      _albumValue('al-1', const AsyncError<Album>('boom', StackTrace.empty)),
    ]));
    await tester.pumpAndSettle();
    expect(find.textContaining('Error'), findsOneWidget);
  });

  testWidgets(
    'AppBar shows outlined download icon when album not marked',
    (WidgetTester tester) async {
      const Album a = Album(id: 'al-1', name: 'X', song: <Song>[
        Song(id: 'so-1', title: 'a'),
      ]);
      await tester.pumpWidget(_wrap('al-1', <Override>[
        _albumValue('al-1', const AsyncData<Album>(a)),
      ]));
      await tester.pumpAndSettle();
      expect(
        find.byIcon(Icons.download_for_offline_outlined),
        findsOneWidget,
      );
    },
  );

  // ---------------------------------------------------------------------
  // M3: add-to-playlist entry points
  // ---------------------------------------------------------------------
  group('add-to-playlist entry points (M3)', () {
    setUp(_StubPlaylistMutations.reset);
    tearDown(_StubPlaylistMutations.reset);

    const Playlist owned = Playlist(
      id: 'pl-owned-1',
      name: 'Morning',
      owner: 'phone',
      songCount: 5,
    );

    const Album twoSongAlbum = Album(
      id: 'al-1',
      name: 'Currents',
      artist: 'Tame Impala',
      song: <Song>[
        Song(id: 'so-1', title: 'Let It Happen'),
        Song(id: 'so-2', title: 'Nangs'),
      ],
    );

    testWidgets(
      'long-press song row → sheet opens → tapping a playlist passes '
      'just that song id to addSongs',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              // navidromeUsername = 'phone' so the seeded owned playlist
              // passes the ownership filter in the sheet.
              secureStorageProvider.overrideWith(
                (Ref<SecureStorage> ref) =>
                    _StaticStorage(<String, String>{
                  'navidrome_username': 'phone',
                }),
              ),
              _albumValue('al-1', const AsyncData<Album>(twoSongAlbum)),
              _playlistsValue(
                const AsyncData<List<Playlist>>(<Playlist>[owned]),
              ),
              playlistMutationsProvider
                  .overrideWith(_StubPlaylistMutations.new),
            ],
            child: const MaterialApp(
              home: AlbumDetailScreen(albumId: 'al-1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.longPress(find.text('Let It Happen'));
        await tester.pumpAndSettle();

        // Sheet rendered.
        expect(find.text('Add 1 song to playlist'), findsOneWidget);

        await tester.tap(find.text('Morning'));
        await tester.pumpAndSettle();

        expect(_StubPlaylistMutations.lastAddPlaylistId, 'pl-owned-1');
        expect(_StubPlaylistMutations.lastAddSongIds, <String>['so-1']);
      },
    );

    testWidgets(
      '"Add album to playlist…" passes the full song-id list to addSongs',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              secureStorageProvider.overrideWith(
                (Ref<SecureStorage> ref) =>
                    _StaticStorage(<String, String>{
                  'navidrome_username': 'phone',
                }),
              ),
              _albumValue('al-1', const AsyncData<Album>(twoSongAlbum)),
              _playlistsValue(
                const AsyncData<List<Playlist>>(<Playlist>[owned]),
              ),
              playlistMutationsProvider
                  .overrideWith(_StubPlaylistMutations.new),
            ],
            child: const MaterialApp(
              home: AlbumDetailScreen(albumId: 'al-1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add album to playlist…'));
        await tester.pumpAndSettle();

        expect(find.text('Add 2 songs to playlist'), findsOneWidget);

        await tester.tap(find.text('Morning'));
        await tester.pumpAndSettle();

        expect(_StubPlaylistMutations.lastAddPlaylistId, 'pl-owned-1');
        expect(
          _StubPlaylistMutations.lastAddSongIds,
          <String>['so-1', 'so-2'],
        );
      },
    );
  });
}

class _StaticStorage implements SecureStorage {
  _StaticStorage(this._values);
  final Map<String, String> _values;

  @override
  Future<String?> read(String key) async => _values[key];
  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}
