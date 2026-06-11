import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/search_response.dart';
import 'package:heerr/models/search_result_item.dart';
import 'package:heerr/models/subsonic/album.dart';
import 'package:heerr/models/subsonic/artist.dart';
import 'package:heerr/models/subsonic/artist_index.dart';
import 'package:heerr/models/subsonic/playlist.dart';
import 'package:heerr/models/subsonic/search_result3.dart';
import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/models/job_view.dart';
import 'package:heerr/models/queue_response.dart';
import 'package:heerr/providers/library/library_albums.dart';
import 'package:heerr/providers/library/library_artists.dart';
import 'package:heerr/providers/library/library_playlists.dart';
import 'package:heerr/providers/library/library_search.dart';
import 'package:heerr/providers/queue.dart';
import 'package:heerr/providers/search.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/screens/library/library_screen.dart';
import 'package:heerr/widgets/empty_state.dart';
import 'package:heerr/widgets/library_result_tile.dart';
import 'package:heerr/widgets/result_tile.dart';
import 'package:heerr/widgets/skeleton.dart';

class _NoopStorage implements SecureStorage {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

Override _artistsValue(AsyncValue<List<ArtistIndex>> value) {
  return libraryArtistsProvider.overrideWith(
    (Ref<AsyncValue<List<ArtistIndex>>> ref) {
      return value.when(
        data: (List<ArtistIndex> v) => Future<List<ArtistIndex>>.value(v),
        loading: () => Completer<List<ArtistIndex>>().future,
        error: (Object e, StackTrace st) =>
            Future<List<ArtistIndex>>.error(e, st),
      );
    },
  );
}

Override _albumsValue(AsyncValue<List<Album>> value) {
  return libraryAlbumsProvider.overrideWith(
    (Ref<AsyncValue<List<Album>>> ref) {
      return value.when(
        data: (List<Album> v) => Future<List<Album>>.value(v),
        loading: () => Completer<List<Album>>().future,
        error: (Object e, StackTrace st) => Future<List<Album>>.error(e, st),
      );
    },
  );
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

class _StubQueue extends Queue {
  @override
  Future<QueueResponse> build() async =>
      const QueueResponse(active: <JobView>[], recent: <JobView>[]);
}

Widget _wrap(List<Override> overrides) {
  return ProviderScope(
    overrides: <Override>[
      secureStorageProvider.overrideWithValue(_NoopStorage()),
      // Stop combinedSearchProvider from triggering a real /queue fetch in
      // search-mode tests (browse-mode tests never read combinedSearch, but
      // the override is harmless there too).
      queueProvider.overrideWith(_StubQueue.new),
      searchDebounceProvider.overrideWithValue(Duration.zero),
      ...overrides,
    ],
    child: const MaterialApp(home: LibraryScreen()),
  );
}

// Defaults: empty-data on the two non-focal tabs so they don't trip up
// rendering when widgets-under-test build the focal tab only.
List<Override> _defaultsExcept({Override? artists, Override? albums, Override? playlists}) {
  return <Override>[
    artists ?? _artistsValue(const AsyncData<List<ArtistIndex>>(<ArtistIndex>[])),
    albums ?? _albumsValue(const AsyncData<List<Album>>(<Album>[])),
    playlists ?? _playlistsValue(const AsyncData<List<Playlist>>(<Playlist>[])),
  ];
}

void main() {
  group('Artists tab (default)', () {
    testWidgets('loading → SkeletonList', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(_defaultsExcept(
        artists: _artistsValue(const AsyncLoading<List<ArtistIndex>>()),
      )));
      await tester.pump();
      expect(find.byType(SkeletonList), findsOneWidget);
    });

    testWidgets('empty library → EmptyState "No artists yet"',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(_defaultsExcept(
        artists:
            _artistsValue(const AsyncData<List<ArtistIndex>>(<ArtistIndex>[])),
      )));
      await tester.pumpAndSettle();
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No artists yet'), findsOneWidget);
    });

    testWidgets('data → renders artist tiles grouped by letter',
        (WidgetTester tester) async {
      const ArtistIndex aIndex = ArtistIndex(
        name: 'T',
        artist: <Artist>[
          Artist(id: 'ar-1', name: 'Tame Impala', albumCount: 4),
        ],
      );
      await tester.pumpWidget(_wrap(_defaultsExcept(
        artists: _artistsValue(
            const AsyncData<List<ArtistIndex>>(<ArtistIndex>[aIndex])),
      )));
      await tester.pumpAndSettle();
      expect(find.text('T'), findsOneWidget);
      expect(find.text('Tame Impala'), findsOneWidget);
      expect(find.byType(LibraryResultTile), findsOneWidget);
    });

    testWidgets('error → renders error message',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(_defaultsExcept(
        artists: _artistsValue(
          const AsyncError<List<ArtistIndex>>('boom', StackTrace.empty),
        ),
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining('Error'), findsOneWidget);
    });
  });

  group('Albums sub-tab', () {
    testWidgets('swiping to Albums shows the data list',
        (WidgetTester tester) async {
      const Album album = Album(
        id: 'al-1',
        name: 'Currents',
        artist: 'Tame Impala',
        coverArt: 'al-1',
      );
      await tester.pumpWidget(_wrap(_defaultsExcept(
        albums: _albumsValue(const AsyncData<List<Album>>(<Album>[album])),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Albums'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Currents'), findsOneWidget);
      expect(find.text('Tame Impala'), findsOneWidget);
    });

    testWidgets('Albums empty → EmptyState "No albums yet"',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(_defaultsExcept(
        albums: _albumsValue(const AsyncData<List<Album>>(<Album>[])),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Albums'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('No albums yet'), findsOneWidget);
    });
  });

  group('Playlists sub-tab', () {
    testWidgets('swiping to Playlists shows the data list',
        (WidgetTester tester) async {
      const Playlist playlist = Playlist(
        id: 'pl-1',
        name: 'Morning',
        songCount: 12,
      );
      await tester.pumpWidget(_wrap(_defaultsExcept(
        playlists:
            _playlistsValue(const AsyncData<List<Playlist>>(<Playlist>[playlist])),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Playlists'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Morning'), findsOneWidget);
      expect(find.text('12 songs'), findsOneWidget);
    });

    testWidgets('Playlists empty → EmptyState "No playlists yet"',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(_defaultsExcept(
        playlists:
            _playlistsValue(const AsyncData<List<Playlist>>(<Playlist>[])),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Playlists'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('No playlists yet'), findsOneWidget);
    });
  });

  group('Search mode', () {
    testWidgets(
      'tapping the search icon swaps in the search TextField',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrap(_defaultsExcept()));
        await tester.pumpAndSettle();

        // Idle Library shows the AppBar "Library" title.
        expect(find.text('Library'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);

        await tester.tap(find.byIcon(Icons.search));
        await tester.pumpAndSettle();

        // The TextField has replaced the title; the AppBar title text is gone.
        expect(find.text('Library'), findsNothing);
        expect(find.byType(TextField), findsOneWidget);
        // Initial empty-query placeholder.
        expect(find.text('Search your library'), findsOneWidget);
      },
    );

    testWidgets(
      'library hits render with the "On YouTube Music" manual button',
      (WidgetTester tester) async {
        const Song s = Song(
          id: 'so-1',
          title: 'Let It Happen',
          artist: 'Tame Impala',
          album: 'Currents',
          albumId: 'al-101',
        );
        const SearchResult3 libHit = SearchResult3(song: <Song>[s]);

        await tester.pumpWidget(_wrap(<Override>[
          ..._defaultsExcept(),
          librarySearchProvider('tame').overrideWith(
            (Ref<AsyncValue<SearchResult3>> ref) async => libHit,
          ),
        ]));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.search));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'tame');
        await tester.pumpAndSettle();

        // Library section + song title rendered.
        expect(find.text('In your library'), findsOneWidget);
        expect(find.text('Let It Happen'), findsOneWidget);
        // YT section header + manual button rendered.
        expect(find.text('On YouTube Music'), findsOneWidget);
        expect(find.text('Search more on YouTube Music'), findsOneWidget);
        // No YT results yet.
        expect(find.byType(ResultTile), findsNothing);
      },
    );

    testWidgets(
      'tapping "Search more on YouTube Music" reveals the YT results',
      (WidgetTester tester) async {
        const Song s = Song(
          id: 'so-1',
          title: 'Let It Happen',
          artist: 'Tame Impala',
        );
        const SearchResult3 libHit = SearchResult3(song: <Song>[s]);
        const SearchResponse ytResp = SearchResponse(
          results: <SearchResultItem>[
            SearchResultItem(
              sourceUrl: 'https://music.youtube.com/watch?v=yt1',
              sourceType: 'song',
              title: 'Let It Happen (Live)',
              artist: 'Tame Impala',
              alreadyDownloaded: false,
            ),
          ],
        );

        await tester.pumpWidget(_wrap(<Override>[
          ..._defaultsExcept(),
          librarySearchProvider('tame').overrideWith(
            (Ref<AsyncValue<SearchResult3>> ref) async => libHit,
          ),
          ytmSearchProvider('tame').overrideWith(
            (Ref<AsyncValue<SearchResponse>> ref) async => ytResp,
          ),
        ]));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.search));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'tame');
        await tester.pumpAndSettle();

        // Button is showing before tap.
        expect(find.text('Search more on YouTube Music'), findsOneWidget);

        await tester.tap(find.text('Search more on YouTube Music'));
        await tester.pumpAndSettle();

        // Button gone, YT result tile present.
        expect(find.text('Search more on YouTube Music'), findsNothing);
        expect(find.text('Let It Happen (Live)'), findsOneWidget);
      },
    );

    testWidgets(
      'empty library auto-fires YT and renders its results',
      (WidgetTester tester) async {
        const SearchResult3 libEmpty = SearchResult3();
        const SearchResponse ytResp = SearchResponse(
          results: <SearchResultItem>[
            SearchResultItem(
              sourceUrl: 'https://music.youtube.com/watch?v=yt1',
              sourceType: 'song',
              title: 'Brand New Song',
              artist: 'Some Artist',
              alreadyDownloaded: false,
            ),
          ],
        );

        await tester.pumpWidget(_wrap(<Override>[
          ..._defaultsExcept(),
          librarySearchProvider('newq').overrideWith(
            (Ref<AsyncValue<SearchResult3>> ref) async => libEmpty,
          ),
          ytmSearchProvider('newq').overrideWith(
            (Ref<AsyncValue<SearchResponse>> ref) async => ytResp,
          ),
        ]));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.search));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'newq');
        await tester.pumpAndSettle();

        // Library section shows "Not in your library." copy.
        expect(find.text('In your library'), findsOneWidget);
        expect(find.text('Not in your library.'), findsOneWidget);
        // YT section auto-fired (no manual button).
        expect(find.text('Search more on YouTube Music'), findsNothing);
        expect(find.text('Brand New Song'), findsOneWidget);
      },
    );

    testWidgets(
      'both library + YT empty → "No matches" EmptyState',
      (WidgetTester tester) async {
        const SearchResult3 libEmpty = SearchResult3();
        const SearchResponse ytEmpty =
            SearchResponse(results: <SearchResultItem>[]);

        await tester.pumpWidget(_wrap(<Override>[
          ..._defaultsExcept(),
          librarySearchProvider('zzz').overrideWith(
            (Ref<AsyncValue<SearchResult3>> ref) async => libEmpty,
          ),
          ytmSearchProvider('zzz').overrideWith(
            (Ref<AsyncValue<SearchResponse>> ref) async => ytEmpty,
          ),
        ]));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.search));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'zzz');
        await tester.pumpAndSettle();

        expect(find.byType(EmptyState), findsOneWidget);
        expect(find.text('No matches'), findsOneWidget);
      },
    );

    testWidgets(
      'back arrow exits search mode',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrap(_defaultsExcept()));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.search));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        // Back to browse mode.
        expect(find.byType(TextField), findsNothing);
        expect(find.text('Library'), findsOneWidget);
      },
    );
  });
}
