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
  static int reorderCalls = 0;
  static int removeCalls = 0;
  static int addCalls = 0;
  static String? lastRenameName;
  static bool? lastRenamePublic;
  static String? lastDeletedId;
  static List<String>? lastReorderIds;
  static List<int>? lastRemoveIndices;

  static void reset() {
    renameCalls = 0;
    deleteCalls = 0;
    reorderCalls = 0;
    removeCalls = 0;
    addCalls = 0;
    lastRenameName = null;
    lastRenamePublic = null;
    lastDeletedId = null;
    lastReorderIds = null;
    lastRemoveIndices = null;
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

  @override
  Future<void> reorder({
    required String playlistId,
    required List<String> newSongIdOrder,
  }) async {
    reorderCalls++;
    lastReorderIds = List<String>.from(newSongIdOrder);
  }

  @override
  Future<void> removeSongsAtIndices({
    required String playlistId,
    required List<int> indices,
  }) async {
    removeCalls++;
    lastRemoveIndices = List<int>.from(indices);
  }

  @override
  Future<void> addSongs({
    required String playlistId,
    required List<String> songIds,
  }) async {
    addCalls++;
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

  // ---------------------------------------------------------------------
  // M4: edit mode — remove songs + reorder
  // ---------------------------------------------------------------------
  group('edit mode (M4)', () {
    setUp(_StubPlaylistMutations.reset);
    tearDown(_StubPlaylistMutations.reset);

    const Playlist ownedFiveSongs = Playlist(
      id: 'pl-1',
      name: 'Morning',
      owner: 'phone',
      public: false,
      entry: <Song>[
        Song(id: 'so-a', title: 'A'),
        Song(id: 'so-b', title: 'B'),
        Song(id: 'so-c', title: 'C'),
        Song(id: 'so-d', title: 'D'),
        Song(id: 'so-e', title: 'E'),
      ],
    );

    testWidgets(
      'Edit button hidden when playlist.owner != navidromeUsername',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrapWithUser(
          'pl-1',
          <Override>[
            _playlistValue(
              'pl-1',
              const AsyncData<Playlist>(ownedFiveSongs),
            ),
          ],
          username: 'someone-else',
        ));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
      },
    );

    testWidgets(
      'Edit button visible when playlist.owner == navidromeUsername',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrapWithUser(
          'pl-1',
          <Override>[
            _playlistValue(
              'pl-1',
              const AsyncData<Playlist>(ownedFiveSongs),
            ),
          ],
          username: 'phone',
        ));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'tapping Edit enters edit mode (Check + drag handles render)',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrapWithUser(
          'pl-1',
          <Override>[
            _playlistValue(
              'pl-1',
              const AsyncData<Playlist>(ownedFiveSongs),
            ),
          ],
          username: 'phone',
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.check), findsOneWidget);
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
        expect(find.byType(ReorderableListView), findsOneWidget);
        expect(
          find.byIcon(Icons.drag_handle),
          findsNWidgets(ownedFiveSongs.entry.length),
        );
        // Default delete handles are the outlined trash icons.
        expect(
          find.byIcon(Icons.delete_outline),
          findsNWidgets(ownedFiveSongs.entry.length),
        );
      },
    );

    testWidgets(
      'remove a row → Save calls removeSongsAtIndices ONLY, '
      'with the original index of the removed song',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrapWithUser(
          'pl-1',
          <Override>[
            _playlistValue(
              'pl-1',
              const AsyncData<Playlist>(ownedFiveSongs),
            ),
            playlistMutationsProvider
                .overrideWith(_StubPlaylistMutations.new),
          ],
          username: 'phone',
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();

        // Mark the third song (index 2: 'C') for removal — tap its
        // delete handle. Each row has one delete_outline icon at this
        // point. We target the one in the row whose title is 'C'.
        final Finder rowC = find.ancestor(
          of: find.text('C'),
          matching: find.byType(ListTile),
        );
        final Finder deleteInC = find.descendant(
          of: rowC,
          matching: find.byIcon(Icons.delete_outline),
        );
        await tester.tap(deleteInC);
        await tester.pumpAndSettle();

        // Save.
        await tester.tap(find.byIcon(Icons.check));
        await tester.pumpAndSettle();

        expect(_StubPlaylistMutations.removeCalls, 1);
        expect(_StubPlaylistMutations.lastRemoveIndices, <int>[2]);
        expect(_StubPlaylistMutations.reorderCalls, 0);
        expect(_StubPlaylistMutations.addCalls, 0);
      },
    );

    testWidgets(
      'reorder two rows → Save calls reorder() ONCE with the new id order',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrapWithUser(
          'pl-1',
          <Override>[
            _playlistValue(
              'pl-1',
              const AsyncData<Playlist>(ownedFiveSongs),
            ),
            playlistMutationsProvider
                .overrideWith(_StubPlaylistMutations.new),
          ],
          username: 'phone',
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();

        // Simulate a drag: move index 0 ('A') to position 2. The new
        // order should be [B, C, A, D, E]. We invoke the
        // ReorderableListView's onReorderItem directly because the
        // gesture-based long-press-and-drag is fragile in unit tests
        // (relies on hit-testing internal Draggable feedback). The
        // callback is the same one user-driven drags fire.
        final ReorderableListView list = tester
            .widget<ReorderableListView>(find.byType(ReorderableListView));
        list.onReorderItem!(0, 2);
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.check));
        await tester.pumpAndSettle();

        expect(_StubPlaylistMutations.reorderCalls, 1);
        expect(
          _StubPlaylistMutations.lastReorderIds,
          <String>['so-b', 'so-c', 'so-a', 'so-d', 'so-e'],
        );
        expect(_StubPlaylistMutations.removeCalls, 0);
        expect(_StubPlaylistMutations.addCalls, 0);
      },
    );

    testWidgets(
      'back with pending edits shows discard dialog; '
      'Discard returns to view mode without firing any mutation',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrapWithUser(
          'pl-1',
          <Override>[
            _playlistValue(
              'pl-1',
              const AsyncData<Playlist>(ownedFiveSongs),
            ),
            playlistMutationsProvider
                .overrideWith(_StubPlaylistMutations.new),
          ],
          username: 'phone',
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();

        // Mark the first row for removal so there's a pending edit.
        final Finder rowA = find.ancestor(
          of: find.text('A'),
          matching: find.byType(ListTile),
        );
        await tester.tap(find.descendant(
          of: rowA,
          matching: find.byIcon(Icons.delete_outline),
        ));
        await tester.pumpAndSettle();

        // Simulate system back. WidgetsBinding.handlePopRoute() drives
        // the PopScope intercept.
        final bool didPop =
            await WidgetsBinding.instance.handlePopRoute();

        await tester.pumpAndSettle();
        // PopScope blocked the pop (because we were editing) and we're
        // now in the discard dialog.
        expect(didPop, isTrue);
        expect(find.text('Discard changes?'), findsOneWidget);

        await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
        await tester.pumpAndSettle();

        // Back to view mode (Edit button is visible again; Check is gone).
        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
        expect(find.byIcon(Icons.check), findsNothing);
        // No mutation fired.
        expect(_StubPlaylistMutations.removeCalls, 0);
        expect(_StubPlaylistMutations.reorderCalls, 0);
      },
    );

    testWidgets(
      'Save with no actual changes is a quiet no-op',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrapWithUser(
          'pl-1',
          <Override>[
            _playlistValue(
              'pl-1',
              const AsyncData<Playlist>(ownedFiveSongs),
            ),
            playlistMutationsProvider
                .overrideWith(_StubPlaylistMutations.new),
          ],
          username: 'phone',
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.check));
        await tester.pumpAndSettle();

        expect(_StubPlaylistMutations.reorderCalls, 0);
        expect(_StubPlaylistMutations.removeCalls, 0);
        // Back to view mode.
        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      },
    );
  });
}
