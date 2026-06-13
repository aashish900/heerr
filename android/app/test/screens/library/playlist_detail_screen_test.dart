import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/playlist.dart';
import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/providers/library/library_playlist.dart';
import 'package:heerr/providers/library/playlist_mutations.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/screens/library/playlist_detail_screen.dart';
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

/// Storage stub that hands back a fixed Navidrome username so
/// `settingsProvider` builds with `navidromeUsername == username`. Used
/// by the M2 owner-edit tests to flip ownership on / off without
/// hand-overriding `settingsProvider` itself.
class _UserStorage implements SecureStorage {
  _UserStorage(this.username);
  final String? username;
  @override
  Future<String?> read(String key) async =>
      key == 'navidrome_username' ? username : null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

class _StubPlaylistMutations extends PlaylistMutations {
  static int renameCalls = 0;
  static int deleteCalls = 0;
  static String? lastRenameName;
  static bool? lastRenamePublic;
  static String? lastDeletedId;

  static void reset() {
    renameCalls = 0;
    deleteCalls = 0;
    lastRenameName = null;
    lastRenamePublic = null;
    lastDeletedId = null;
  }

  @override
  void build() {}

  @override
  Future<void> renamePlaylist({
    required String playlistId,
    required String name,
    bool? makePublic,
  }) async {
    renameCalls++;
    lastRenameName = name;
    lastRenamePublic = makePublic;
  }

  @override
  Future<void> deletePlaylist(String playlistId) async {
    deleteCalls++;
    lastDeletedId = playlistId;
  }
}

Override _playlistValue(String id, AsyncValue<Playlist> value) {
  return libraryPlaylistProvider(id).overrideWith(
    (Ref<AsyncValue<Playlist>> ref) {
      return value.when(
        data: (Playlist p) => Future<Playlist>.value(p),
        loading: () => Completer<Playlist>().future,
        error: (Object e, StackTrace st) => Future<Playlist>.error(e, st),
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
    child: MaterialApp(home: PlaylistDetailScreen(playlistId: id)),
  );
}

/// Variant of [_wrap] that wires a [_UserStorage] so `settingsProvider`
/// resolves [navidromeUsername]. Required for the owner-gated edit-mode
/// tests at M2.
Widget _wrapWithUser(
  String id,
  List<Override> overrides, {
  required String? username,
}) {
  return ProviderScope(
    overrides: <Override>[
      secureStorageProvider.overrideWithValue(_UserStorage(username)),
      ...overrides,
    ],
    child: MaterialApp(home: PlaylistDetailScreen(playlistId: id)),
  );
}

void main() {
  testWidgets('loading → SkeletonList', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap('pl-1', <Override>[
      _playlistValue('pl-1', const AsyncLoading<Playlist>()),
    ]));
    await tester.pump();
    expect(find.byType(SkeletonList), findsOneWidget);
  });

  testWidgets('empty (no entries) → EmptyState "Empty playlist"',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap('pl-1', <Override>[
      _playlistValue(
        'pl-1',
        const AsyncData<Playlist>(Playlist(id: 'pl-1', name: 'X')),
      ),
    ]));
    await tester.pumpAndSettle();
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Empty playlist'), findsOneWidget);
  });

  testWidgets(
    'data → renders header + entry list',
    (WidgetTester tester) async {
      const Playlist p = Playlist(
        id: 'pl-1',
        name: 'Morning',
        owner: 'phone',
        songCount: 2,
        entry: <Song>[
          Song(id: 'so-1', title: 'Let It Happen', artist: 'Tame Impala'),
          Song(id: 'so-2', title: 'Nangs', artist: 'Tame Impala'),
        ],
      );
      await tester.pumpWidget(_wrap('pl-1', <Override>[
        _playlistValue('pl-1', const AsyncData<Playlist>(p)),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('by phone'), findsOneWidget);
      expect(find.text('2 songs'), findsOneWidget);
      expect(find.text('Let It Happen'), findsOneWidget);
      expect(find.text('Nangs'), findsOneWidget);
    },
  );

  testWidgets('error → renders error message',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap('pl-1', <Override>[
      _playlistValue('pl-1', const AsyncError<Playlist>('boom', StackTrace.empty)),
    ]));
    await tester.pumpAndSettle();
    expect(find.textContaining('Error'), findsOneWidget);
  });

  testWidgets(
    'AppBar shows outlined download icon when playlist not marked',
    (WidgetTester tester) async {
      const Playlist p = Playlist(id: 'pl-1', name: 'X', entry: <Song>[
        Song(id: 'so-1', title: 'a'),
      ]);
      await tester.pumpWidget(_wrap('pl-1', <Override>[
        _playlistValue('pl-1', const AsyncData<Playlist>(p)),
      ]));
      await tester.pumpAndSettle();
      expect(
        find.byIcon(Icons.download_for_offline_outlined),
        findsOneWidget,
      );
    },
  );

  // ---------------------------------------------------------------------
  // M2: edit menu (rename / delete) — owner-gated by Playlist.owner
  // matching SettingsValue.navidromeUsername.
  // ---------------------------------------------------------------------
  group('edit overflow menu (M2)', () {
    setUp(_StubPlaylistMutations.reset);
    tearDown(_StubPlaylistMutations.reset);

    const Playlist owned = Playlist(
      id: 'pl-1',
      name: 'Morning',
      owner: 'phone',
      public: false,
      entry: <Song>[Song(id: 'so-1', title: 'a')],
    );

    testWidgets(
      'overflow menu hidden when playlist.owner != navidromeUsername',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrapWithUser(
          'pl-1',
          <Override>[
            _playlistValue('pl-1', const AsyncData<Playlist>(owned)),
          ],
          username: 'someone-else',
        ));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.more_vert), findsNothing);
      },
    );

    testWidgets(
      'overflow menu hidden when no Navidrome username is configured',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrapWithUser(
          'pl-1',
          <Override>[
            _playlistValue('pl-1', const AsyncData<Playlist>(owned)),
          ],
          username: null,
        ));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.more_vert), findsNothing);
      },
    );

    testWidgets(
      'overflow menu visible when playlist.owner == navidromeUsername',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrapWithUser(
          'pl-1',
          <Override>[
            _playlistValue('pl-1', const AsyncData<Playlist>(owned)),
          ],
          username: 'phone',
        ));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.more_vert), findsOneWidget);
      },
    );

    testWidgets(
      'Rename → submit calls renamePlaylist with new name + makePublic',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrapWithUser(
          'pl-1',
          <Override>[
            _playlistValue('pl-1', const AsyncData<Playlist>(owned)),
            playlistMutationsProvider
                .overrideWith(_StubPlaylistMutations.new),
          ],
          username: 'phone',
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rename…'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'Morning Coffee');
        await tester.pump();
        await tester.tap(find.byType(CheckboxListTile)); // → public=true
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();

        expect(_StubPlaylistMutations.renameCalls, 1);
        expect(_StubPlaylistMutations.lastRenameName, 'Morning Coffee');
        expect(_StubPlaylistMutations.lastRenamePublic, isTrue);
      },
    );

    testWidgets(
      'Delete → confirmation dialog required before deletePlaylist fires',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrapWithUser(
          'pl-1',
          <Override>[
            _playlistValue('pl-1', const AsyncData<Playlist>(owned)),
            playlistMutationsProvider
                .overrideWith(_StubPlaylistMutations.new),
          ],
          username: 'phone',
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete…'));
        await tester.pumpAndSettle();

        // Cancel: nothing should happen.
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        expect(_StubPlaylistMutations.deleteCalls, 0);

        // Reopen + confirm.
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete…'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await tester.pumpAndSettle();

        expect(_StubPlaylistMutations.deleteCalls, 1);
        expect(_StubPlaylistMutations.lastDeletedId, 'pl-1');
      },
    );
  });
}
