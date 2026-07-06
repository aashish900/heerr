import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rxdart/rxdart.dart';

import 'package:heerr/models/subsonic/playlist.dart';
import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/player/heerr_audio_handler.dart';
import 'package:heerr/player/player_provider.dart';
import 'package:heerr/providers/library/library_playlists.dart';
import 'package:heerr/providers/library/playlist_mutations.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/widgets/add_to_playlist_sheet.dart';

import '../support/cred_test_support.dart';

/// No-op secure storage — credentials now come from the active profile (A1),
/// supplied via [activeProfileOverride] in [_openSheet].
class _NoopStorage implements SecureStorage {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

class _StubPlaylistMutations extends PlaylistMutations {
  static int createCalls = 0;
  static int addCalls = 0;
  static String? lastCreateName;
  static List<String>? lastCreateSongIds;
  static String? lastAddPlaylistId;
  static List<String>? lastAddSongIds;

  /// Optional override for the return value of `addSongs` — lets dedupe
  /// tests simulate "M of N songs added" without rewiring the routing
  /// adapter. Defaults to `songIds.length` (no dedupe).
  static int Function(List<String>)? addReturn;

  static void reset() {
    createCalls = 0;
    addCalls = 0;
    lastCreateName = null;
    lastCreateSongIds = null;
    lastAddPlaylistId = null;
    lastAddSongIds = null;
    addReturn = null;
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
    lastCreateSongIds = List<String>.from(songIds);
    return Playlist(id: 'new-pl', name: name);
  }

  @override
  Future<int> addSongs({
    required String playlistId,
    required List<String> songIds,
  }) async {
    addCalls++;
    lastAddPlaylistId = playlistId;
    lastAddSongIds = List<String>.from(songIds);
    return addReturn?.call(songIds) ?? songIds.length;
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

/// Mount the sheet by tapping a button that calls
/// `AddToPlaylistSheet.show(...)`. Lets us assert on the sheet AND on
/// the host's `ScaffoldMessenger` after the sheet pops.
Future<void> _openSheet(
  WidgetTester tester, {
  required List<String> songIds,
  required List<Override> overrides,
  String? username,
  List<Song> queueSongs = const <Song>[],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        secureStorageProvider.overrideWithValue(_NoopStorage()),
        if (username != null) activeProfileOverride(navidromeUsername: username),
        ...overrides,
      ],
      child: MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => AddToPlaylistSheet.show(
                  context: context,
                  songIds: songIds,
                  queueSongs: queueSongs,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// #35: stubbed audio handler for the "Add to queue" tile tests. `queue`
/// is a real BehaviorSubject so the action's `queue.value.isEmpty` branch
/// works; the transport methods record calls via mocktail.
class _StubHandler extends Mock implements HeerrAudioHandler {}

void main() {
  initPrefsMock();
  setUp(_StubPlaylistMutations.reset);
  tearDown(_StubPlaylistMutations.reset);

  const Playlist owned1 = Playlist(
    id: 'pl-owned-1',
    name: 'Morning',
    owner: 'phone',
    songCount: 12,
  );
  const Playlist owned2 = Playlist(
    id: 'pl-owned-2',
    name: 'Workout',
    owner: 'phone',
    songCount: 7,
  );
  const Playlist someoneElses = Playlist(
    id: 'pl-shared',
    name: 'Shared mix',
    owner: 'someone-else',
    songCount: 30,
  );

  group('AddToPlaylistSheet — rendering', () {
    testWidgets('renders title + Create-new row + owned playlists only', (
      WidgetTester tester,
    ) async {
      await _openSheet(
        tester,
        songIds: const <String>['so-1'],
        overrides: <Override>[
          _playlistsValue(const AsyncData<List<Playlist>>(<Playlist>[
            owned1,
            someoneElses,
            owned2,
          ])),
          playlistMutationsProvider.overrideWith(_StubPlaylistMutations.new),
        ],
        username: 'phone',
      );

      expect(find.text('Add 1 song to playlist'), findsOneWidget);
      await tester.tap(find.text('Add to playlist'));
      await tester.pumpAndSettle();
      expect(find.text('Create new playlist…'), findsOneWidget);
      expect(find.text('Morning'), findsOneWidget);
      expect(find.text('Workout'), findsOneWidget);
      // Ownership filter drops playlists owned by someone else.
      expect(find.text('Shared mix'), findsNothing);
    });

    testWidgets(
      'pluralises the song-count label correctly',
      (WidgetTester tester) async {
        await _openSheet(
          tester,
          songIds: const <String>['s1', 's2', 's3'],
          overrides: <Override>[
            _playlistsValue(
              const AsyncData<List<Playlist>>(<Playlist>[]),
            ),
            playlistMutationsProvider
                .overrideWith(_StubPlaylistMutations.new),
          ],
          username: 'phone',
        );
        expect(find.text('Add 3 songs to playlist'), findsOneWidget);
      },
    );

    testWidgets(
      'no editable playlists → nudge copy that points at the create-new row',
      (WidgetTester tester) async {
        await _openSheet(
          tester,
          songIds: const <String>['so-1'],
          overrides: <Override>[
            _playlistsValue(const AsyncData<List<Playlist>>(<Playlist>[
              someoneElses,
            ])),
            playlistMutationsProvider
                .overrideWith(_StubPlaylistMutations.new),
          ],
          username: 'phone',
        );
        await tester.tap(find.text('Add to playlist'));
        await tester.pumpAndSettle();
        expect(find.text('Create new playlist…'), findsOneWidget);
        expect(
          find.textContaining('No editable playlists yet'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'no Navidrome username → ownership filter zeroes the list',
      (WidgetTester tester) async {
        await _openSheet(
          tester,
          songIds: const <String>['so-1'],
          overrides: <Override>[
            _playlistsValue(const AsyncData<List<Playlist>>(<Playlist>[
              owned1,
              owned2,
            ])),
            playlistMutationsProvider
                .overrideWith(_StubPlaylistMutations.new),
          ],
          username: null,
        );
        await tester.tap(find.text('Add to playlist'));
        await tester.pumpAndSettle();
        expect(find.text('Morning'), findsNothing);
        expect(find.text('Workout'), findsNothing);
        expect(
          find.textContaining('No editable playlists yet'),
          findsOneWidget,
        );
      },
    );
  });

  group('AddToPlaylistSheet — actions', () {
    testWidgets(
      'tap existing playlist → addSongs called with playlistId + songIds; '
      'sheet pops; snackbar shown',
      (WidgetTester tester) async {
        await _openSheet(
          tester,
          songIds: const <String>['so-1', 'so-2'],
          overrides: <Override>[
            _playlistsValue(const AsyncData<List<Playlist>>(<Playlist>[
              owned1,
            ])),
            playlistMutationsProvider
                .overrideWith(_StubPlaylistMutations.new),
          ],
          username: 'phone',
        );

        await tester.tap(find.text('Add to playlist'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Morning'));
        await tester.pumpAndSettle();

        expect(_StubPlaylistMutations.addCalls, 1);
        expect(_StubPlaylistMutations.lastAddPlaylistId, 'pl-owned-1');
        expect(
          _StubPlaylistMutations.lastAddSongIds,
          <String>['so-1', 'so-2'],
        );
        // Sheet is gone.
        expect(find.text('Create new playlist…'), findsNothing);
        // Snackbar surfaced on the host scaffold.
        expect(
          find.textContaining("Added 2 songs to 'Morning'"),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tap "Create new playlist…" → CreatePlaylistDialog → confirm calls '
      'createPlaylist(name, songIds)',
      (WidgetTester tester) async {
        await _openSheet(
          tester,
          songIds: const <String>['so-1', 'so-2'],
          overrides: <Override>[
            _playlistsValue(const AsyncData<List<Playlist>>(<Playlist>[])),
            playlistMutationsProvider
                .overrideWith(_StubPlaylistMutations.new),
          ],
          username: 'phone',
        );

        await tester.tap(find.text('Add to playlist'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create new playlist…'));
        await tester.pumpAndSettle();

        // Dialog is up.
        expect(find.text('New playlist'), findsOneWidget);
        await tester.enterText(find.byType(TextField), '  Roadtrip  ');
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Create'));
        await tester.pumpAndSettle();

        expect(_StubPlaylistMutations.createCalls, 1);
        expect(_StubPlaylistMutations.lastCreateName, 'Roadtrip');
        expect(
          _StubPlaylistMutations.lastCreateSongIds,
          <String>['so-1', 'so-2'],
        );
        // Snackbar surfaced on the host scaffold.
        expect(
          find.textContaining("Created 'Roadtrip' with 2 songs"),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Create-new dialog cancel leaves the sheet open + no mutation',
      (WidgetTester tester) async {
        await _openSheet(
          tester,
          songIds: const <String>['so-1'],
          overrides: <Override>[
            _playlistsValue(const AsyncData<List<Playlist>>(<Playlist>[])),
            playlistMutationsProvider
                .overrideWith(_StubPlaylistMutations.new),
          ],
          username: 'phone',
        );

        await tester.tap(find.text('Add to playlist'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create new playlist…'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(_StubPlaylistMutations.createCalls, 0);
        // Sheet is still up.
        expect(find.text('Create new playlist…'), findsOneWidget);
      },
    );

    testWidgets(
      'all duplicates (added == 0) → snackbar reads "Already in \'<name>\'"',
      (WidgetTester tester) async {
        _StubPlaylistMutations.addReturn = (List<String> _) => 0;
        await _openSheet(
          tester,
          songIds: const <String>['so-1', 'so-2'],
          overrides: <Override>[
            _playlistsValue(
              const AsyncData<List<Playlist>>(<Playlist>[owned1]),
            ),
            playlistMutationsProvider
                .overrideWith(_StubPlaylistMutations.new),
          ],
          username: 'phone',
        );

        await tester.tap(find.text('Add to playlist'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Morning'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining("Already in 'Morning'"),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'partial duplicates → snackbar reports skipped count',
      (WidgetTester tester) async {
        // 3 requested, 2 added → 1 skipped.
        _StubPlaylistMutations.addReturn = (List<String> _) => 2;
        await _openSheet(
          tester,
          songIds: const <String>['so-1', 'so-2', 'so-3'],
          overrides: <Override>[
            _playlistsValue(
              const AsyncData<List<Playlist>>(<Playlist>[owned1]),
            ),
            playlistMutationsProvider
                .overrideWith(_StubPlaylistMutations.new),
          ],
          username: 'phone',
        );

        await tester.tap(find.text('Add to playlist'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Morning'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            "Added 2 songs to 'Morning' (1 already there)",
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('AddToPlaylistSheet — add to queue (#35)', () {
    const Song songA = Song(id: 's-a', title: 'Alpha');
    const Song songB = Song(id: 's-b', title: 'Beta');
    const Key tileKey = Key('add-to-playlist-add-to-queue');

    late _StubHandler handler;

    setUpAll(() {
      registerFallbackValue(const <MediaItem>[]);
    });

    setUp(() {
      handler = _StubHandler();
      when(() => handler.addQueueItems(any())).thenAnswer((_) async {});
      when(() => handler.playAll(any(),
          startIndex: any(named: 'startIndex'))).thenAnswer((_) async {});
    });

    List<Override> queueOverrides(List<MediaItem> currentQueue) {
      final BehaviorSubject<List<MediaItem>> subject =
          BehaviorSubject<List<MediaItem>>.seeded(currentQueue);
      addTearDown(subject.close);
      when(() => handler.queue).thenAnswer((_) => subject);
      return <Override>[
        _playlistsValue(const AsyncValue<List<Playlist>>.data(<Playlist>[])),
        audioHandlerProvider.overrideWithValue(handler),
      ];
    }

    testWidgets('tile hidden when queueSongs is empty', (
      WidgetTester tester,
    ) async {
      await _openSheet(
        tester,
        songIds: <String>['s-a'],
        username: 'me',
        overrides: <Override>[
          _playlistsValue(const AsyncValue<List<Playlist>>.data(<Playlist>[])),
        ],
      );
      expect(find.byKey(tileKey), findsNothing);
    });

    testWidgets('appends behind a non-empty queue, pops, snackbars', (
      WidgetTester tester,
    ) async {
      await _openSheet(
        tester,
        songIds: <String>['s-a'],
        username: 'me',
        queueSongs: const <Song>[songA],
        overrides: queueOverrides(const <MediaItem>[
          MediaItem(id: 'https://x/playing', title: 'Playing now'),
        ]),
      );
      await tester.tap(find.byKey(tileKey));
      await tester.pumpAndSettle();

      final List<MediaItem> added = verify(
        () => handler.addQueueItems(captureAny()),
      ).captured.single as List<MediaItem>;
      expect(added, hasLength(1));
      expect(added.single.title, 'Alpha');
      verifyNever(() => handler.playAll(any(),
          startIndex: any(named: 'startIndex')));
      expect(find.byKey(tileKey), findsNothing); // sheet popped
      expect(find.text('Added to queue: Alpha'), findsOneWidget);
    });

    testWidgets('empty queue → starts playback instead of appending', (
      WidgetTester tester,
    ) async {
      await _openSheet(
        tester,
        songIds: <String>['s-a', 's-b'],
        username: 'me',
        queueSongs: const <Song>[songA, songB],
        overrides: queueOverrides(const <MediaItem>[]),
      );
      await tester.tap(find.byKey(tileKey));
      await tester.pumpAndSettle();

      final List<MediaItem> played = verify(
        () => handler.playAll(captureAny(),
            startIndex: any(named: 'startIndex')),
      ).captured.single as List<MediaItem>;
      expect(played, hasLength(2));
      verifyNever(() => handler.addQueueItems(any()));
      expect(find.text('Playing 2 songs'), findsOneWidget);
    });
  });
}
