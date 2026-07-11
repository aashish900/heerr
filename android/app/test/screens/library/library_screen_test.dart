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
import 'package:heerr/providers/library/most_played_artists.dart';
import 'package:heerr/providers/library/playlist_mutations.dart';
import 'package:heerr/providers/queue.dart';
import 'package:heerr/providers/search.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/screens/library/album_grid_card.dart';
import 'package:heerr/screens/library/library_screen.dart';
import 'package:heerr/widgets/empty_state.dart';
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

/// Stub for the M1 PlaylistMutations notifier. Records `createPlaylist`
/// invocations for the FAB-driven flow at M2 — instance state is exposed
/// through static fields because Riverpod owns the notifier lifetime and
/// the test only needs the call count, not a handle to the instance.
class _StubPlaylistMutations extends PlaylistMutations {
  static int createCalls = 0;
  static String? lastCreateName;
  static Playlist Function(String name)? createBuilder;

  static void reset() {
    createCalls = 0;
    lastCreateName = null;
    createBuilder = null;
  }

  @override
  void build() {}

  @override
  Future<Playlist> createPlaylist({
    required String name,
    List<String> songIds = const <String>[],
  }) async {
    createCalls++;
    lastCreateName = name;
    final Playlist Function(String)? b = createBuilder;
    if (b != null) return b(name);
    return Playlist(id: 'new-pl', name: name);
  }
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
// rendering when widgets-under-test build the focal tab only. The
// most-played rail defaults to empty so the Artists tab never fans out a
// real frequent-albums fetch in tests.
List<Override> _defaultsExcept(
    {Override? artists,
    Override? albums,
    Override? playlists,
    List<MostPlayedArtist> mostPlayed = const <MostPlayedArtist>[]}) {
  return <Override>[
    artists ?? _artistsValue(const AsyncData<List<ArtistIndex>>(<ArtistIndex>[])),
    albums ?? _albumsValue(const AsyncData<List<Album>>(<Album>[])),
    playlists ?? _playlistsValue(const AsyncData<List<Playlist>>(<Playlist>[])),
    mostPlayedArtistsProvider.overrideWith(
      (Ref<AsyncValue<List<MostPlayedArtist>>> ref) async => mostPlayed,
    ),
  ];
}

void main() {
  group('X1 header + tabs', () {
    testWidgets('browse mode renders the branded header and headline',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(_defaultsExcept()));
      await tester.pumpAndSettle();
      expect(find.text('Your Library'), findsOneWidget);
      // Shared header: profile avatar + queue shortcut + search action.
      expect(find.byKey(const Key('home-profile-avatar')), findsOneWidget);
      expect(find.byIcon(Icons.queue_music_outlined), findsWidgets);
      expect(find.byIcon(Icons.search), findsOneWidget);
      // No legacy plain title.
      expect(find.text('Library'), findsNothing);
    });

    testWidgets('tab order is Albums / Artists / Playlists',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(_defaultsExcept()));
      await tester.pumpAndSettle();
      final TabBar bar = tester.widget<TabBar>(find.byType(TabBar));
      expect(bar.tabs, hasLength(3));
      // Label order inside the TabBar.
      final Finder labels = find.descendant(
        of: find.byType(TabBar),
        matching: find.byType(Text),
      );
      final List<String> texts = tester
          .widgetList<Text>(labels)
          .map((Text t) => t.data)
          .whereType<String>()
          .toList();
      expect(texts, <String>['Albums', 'Artists', 'Playlists']);
    });

    testWidgets('initialTabIndex: 2 opens the Playlists tab',
        (WidgetTester tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: <Override>[
          secureStorageProvider.overrideWithValue(_NoopStorage()),
          queueProvider.overrideWith(_StubQueue.new),
          searchDebounceProvider.overrideWithValue(Duration.zero),
          ..._defaultsExcept(),
        ],
        child: const MaterialApp(home: LibraryScreen(initialTabIndex: 2)),
      ));
      await tester.pumpAndSettle();
      // The Playlists tab always renders the For You entry.
      expect(
          find.byKey(const Key('library-for-you-entry')), findsOneWidget);
    });
  });

  group('Albums tab (default)', () {
    testWidgets('loading → SkeletonList', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(_defaultsExcept(
        albums: _albumsValue(const AsyncLoading<List<Album>>()),
      )));
      await tester.pump();
      expect(find.byType(SkeletonList), findsOneWidget);
    });

    testWidgets('default tab shows the grid card + full-list row (X3)',
        (WidgetTester tester) async {
      const Album album = Album(
        id: 'al-1',
        name: 'Currents',
        artist: 'Tame Impala',
        coverArt: 'al-1',
        year: 2015,
        songCount: 13,
      );
      await tester.pumpWidget(_wrap(_defaultsExcept(
        albums: _albumsValue(const AsyncData<List<Album>>(<Album>[album])),
      )));
      await tester.pumpAndSettle();

      // Grid card renders above the fold, with the chip row.
      expect(find.byType(AlbumGridCard), findsOneWidget);
      expect(find.text('Currents'), findsOneWidget);
      expect(find.text('Recently Added'), findsOneWidget);
      expect(find.text('Downloaded'), findsOneWidget);

      // The full-list section sits below the grid — scroll it into view.
      await tester.drag(
          find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();
      // List row subtitle joins artist • year • songs.
      expect(find.text('Tame Impala • 2015 • 13 songs'), findsOneWidget);
    });

    testWidgets('grid caps at 9 cards; list carries all albums (X3)',
        (WidgetTester tester) async {
      final List<Album> albums = List<Album>.generate(
        12,
        (int i) => Album(id: 'al-$i', name: 'Album $i'),
      );
      await tester.pumpWidget(_wrap(_defaultsExcept(
        albums: _albumsValue(AsyncData<List<Album>>(albums)),
      )));
      await tester.pumpAndSettle();

      // Grid children are built lazily, but the delegate's childCount is
      // the contract — read it off the SliverGrid.
      final SliverGrid grid =
          tester.widget<SliverGrid>(find.byType(SliverGrid, skipOffstage: false));
      expect(grid.delegate.estimatedChildCount, 9);
      final SliverFixedExtentList list = tester.widget<SliverFixedExtentList>(
          find.byType(SliverFixedExtentList, skipOffstage: false));
      expect(list.delegate.estimatedChildCount, 12);
    });

    testWidgets(
        'A–Z sort shows the alphabet scrubber; scrubbing jumps the list (X4)',
        (WidgetTester tester) async {
      final List<Album> albums = List<Album>.generate(
        30,
        (int i) =>
            Album(id: 'al-$i', name: '${String.fromCharCode(65 + (i % 26))}lbum $i'),
      );
      await tester.pumpWidget(_wrap(_defaultsExcept(
        albums: _albumsValue(AsyncData<List<Album>>(albums)),
      )));
      await tester.pumpAndSettle();

      // Default sort (Recently Added) → no scrubber.
      expect(find.byKey(const Key('alphabet-scrubber')), findsNothing);

      // Switch to A–Z via the sort chip.
      await tester.tap(find.byKey(const Key('library-sort-chip')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A–Z').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('alphabet-scrubber')), findsOneWidget);

      // Scrub near the bottom → the scroll view jumps well past the top.
      final ScrollableState scrollable = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final Offset bottom = tester
          .getBottomLeft(find.byKey(const Key('alphabet-scrubber')))
          .translate(10, -2);
      await tester.tapAt(bottom);
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, greaterThan(0));
    });

    testWidgets('Albums empty → EmptyState "No albums yet"',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(_defaultsExcept(
        albums: _albumsValue(const AsyncData<List<Album>>(<Album>[])),
      )));
      await tester.pumpAndSettle();
      expect(find.text('No albums yet'), findsOneWidget);
    });
  });

  group('Artists sub-tab', () {
    Future<void> goToArtists(WidgetTester tester) async {
      await tester.tap(find.descendant(
        of: find.byType(TabBar),
        matching: find.text('Artists'),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('empty library → EmptyState "No artists yet"',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(_defaultsExcept(
        artists:
            _artistsValue(const AsyncData<List<ArtistIndex>>(<ArtistIndex>[])),
      )));
      await tester.pumpAndSettle();
      await goToArtists(tester);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No artists yet'), findsOneWidget);
    });

    testWidgets('data → flattened rows with album counts + scrubber (X5)',
        (WidgetTester tester) async {
      const List<ArtistIndex> indices = <ArtistIndex>[
        ArtistIndex(name: 'T', artist: <Artist>[
          Artist(id: 'ar-1', name: 'Tame Impala', albumCount: 4),
        ]),
        ArtistIndex(name: 'A', artist: <Artist>[
          Artist(id: 'ar-2', name: 'Adele', albumCount: 2),
        ]),
      ];
      await tester.pumpWidget(_wrap(_defaultsExcept(
        artists: _artistsValue(
            const AsyncData<List<ArtistIndex>>(indices)),
      )));
      await tester.pumpAndSettle();
      await goToArtists(tester);
      expect(find.text('Tame Impala'), findsOneWidget);
      expect(find.text('4 albums'), findsOneWidget);
      // Flattened A–Z: Adele's row is above Tame Impala's.
      expect(
        tester.getTopLeft(find.text('Adele')).dy,
        lessThan(tester.getTopLeft(find.text('Tame Impala')).dy),
      );
      // A–Z is the default artist sort → scrubber visible.
      expect(find.byKey(const Key('alphabet-scrubber')), findsOneWidget);
    });

    testWidgets('most played rail renders entries with play badges (X5)',
        (WidgetTester tester) async {
      const List<MostPlayedArtist> rail = <MostPlayedArtist>[
        MostPlayedArtist(
            artistId: 'ar-w', name: 'The Weeknd', topAlbumId: 'al-1'),
      ];
      const ArtistIndex aIndex = ArtistIndex(
        name: 'T',
        artist: <Artist>[
          Artist(id: 'ar-1', name: 'Tame Impala', albumCount: 4),
        ],
      );
      await tester.pumpWidget(_wrap(_defaultsExcept(
        artists: _artistsValue(
            const AsyncData<List<ArtistIndex>>(<ArtistIndex>[aIndex])),
        mostPlayed: rail,
      )));
      await tester.pumpAndSettle();
      await goToArtists(tester);
      expect(find.text('Most Played Artists'), findsOneWidget);
      expect(find.text('The Weeknd'), findsOneWidget);
      expect(
          find.byKey(const Key('most-played-play-ar-w')), findsOneWidget);
    });

    testWidgets('error → renders error message',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(_defaultsExcept(
        artists: _artistsValue(
          const AsyncError<List<ArtistIndex>>('boom', StackTrace.empty),
        ),
      )));
      await tester.pumpAndSettle();
      await goToArtists(tester);
      expect(find.textContaining('Error'), findsOneWidget);
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

    testWidgets(
      'Playlists empty → For You entry point still visible (N3)',
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
        // M2 empty state replaced by always-visible For You entry — N3
        // makes recommendations reachable even before the user has any
        // playlists.
        expect(find.byKey(const Key('library-for-you-entry')),
            findsOneWidget);
      },
    );

    testWidgets(
      'FAB is rendered on the Playlists sub-tab',
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

        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.text('New playlist'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping FAB + entering name calls createPlaylist once with the name',
      (WidgetTester tester) async {
        _StubPlaylistMutations.reset();
        addTearDown(_StubPlaylistMutations.reset);

        await tester.pumpWidget(_wrap(
          <Override>[
            ..._defaultsExcept(
              playlists: _playlistsValue(
                const AsyncData<List<Playlist>>(<Playlist>[]),
              ),
            ),
            playlistMutationsProvider.overrideWith(_StubPlaylistMutations.new),
          ],
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.descendant(
          of: find.byType(TabBar),
          matching: find.text('Playlists'),
        ));
        await tester.pumpAndSettle();

        // Open the dialog via the FAB.
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        // Enter a name with surrounding whitespace to also assert the
        // dialog's trim contract from M2.
        await tester.enterText(find.byType(TextField), '  Workout  ');
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Create'));
        await tester.pumpAndSettle();

        expect(_StubPlaylistMutations.createCalls, 1);
        expect(_StubPlaylistMutations.lastCreateName, 'Workout');
      },
    );
  });

  group('Search mode', () {
    testWidgets(
      'tapping the search icon swaps in the search TextField',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrap(_defaultsExcept()));
        await tester.pumpAndSettle();

        // Idle Library shows the "Your Library" headline.
        expect(find.text('Your Library'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);

        await tester.tap(find.byIcon(Icons.search));
        await tester.pumpAndSettle();

        // The TextField has replaced the browse UI; the headline is gone.
        expect(find.text('Your Library'), findsNothing);
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
        expect(find.text('Your Library'), findsOneWidget);
      },
    );
  });
}
