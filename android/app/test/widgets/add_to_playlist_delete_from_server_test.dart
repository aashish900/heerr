import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/playlist.dart';
import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/providers/library/library_delete.dart';
import 'package:heerr/providers/library/library_playlists.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/widgets/add_to_playlist_sheet.dart';

import '../support/cred_test_support.dart';

// W1 (#41): "Delete from server…" tile in the add-to-playlist sheet.

class _NoopStorage implements SecureStorage {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

class _StubLibraryDelete extends LibraryDelete {
  static int serverCalls = 0;
  static Song? lastSong;

  static void reset() {
    serverCalls = 0;
    lastSong = null;
  }

  @override
  void build() {}

  @override
  Future<void> deleteFromServer(Song song) async {
    serverCalls++;
    lastSong = song;
  }
}

const Key _deleteKey = Key('add-to-playlist-delete-from-server');

const Song _withPath = Song(
  id: 's1',
  title: 'Pathful',
  path: 'Artist/Album/01 - Pathful.mp3',
);

const Song _noPath = Song(id: 's2', title: 'Pathless');

Future<void> _openSheet(
  WidgetTester tester, {
  Song? deleteFromServerSong,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        secureStorageProvider.overrideWithValue(_NoopStorage()),
        activeProfileOverride(),
        libraryPlaylistsProvider.overrideWith(
          (Ref<AsyncValue<List<Playlist>>> ref) =>
              Future<List<Playlist>>.value(<Playlist>[]),
        ),
        libraryDeleteProvider.overrideWith(_StubLibraryDelete.new),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => AddToPlaylistSheet.show(
                  context: context,
                  songIds: <String>[
                    if (deleteFromServerSong != null) deleteFromServerSong.id,
                  ],
                  deleteFromServerSong: deleteFromServerSong,
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

void main() {
  setUp(_StubLibraryDelete.reset);

  testWidgets('tile renders when the song has a server path',
      (WidgetTester tester) async {
    await _openSheet(tester, deleteFromServerSong: _withPath);
    expect(find.byKey(_deleteKey), findsOneWidget);
  });

  testWidgets('tile is absent when no song is passed',
      (WidgetTester tester) async {
    await _openSheet(tester);
    expect(find.byKey(_deleteKey), findsNothing);
  });

  testWidgets('tile is absent when the song has no path',
      (WidgetTester tester) async {
    await _openSheet(tester, deleteFromServerSong: _noPath);
    expect(find.byKey(_deleteKey), findsNothing);
  });

  testWidgets('confirm dialog gates the delete; confirm fires it and pops',
      (WidgetTester tester) async {
    await _openSheet(tester, deleteFromServerSong: _withPath);

    await tester.tap(find.byKey(_deleteKey));
    await tester.pumpAndSettle();
    expect(find.text('Delete from server?'), findsOneWidget);
    expect(_StubLibraryDelete.serverCalls, 0);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(_StubLibraryDelete.serverCalls, 1);
    expect(_StubLibraryDelete.lastSong?.id, 's1');
    // sheet popped + snackbar on the host scaffold
    expect(find.byKey(_deleteKey), findsNothing);
    expect(find.textContaining('from server'), findsOneWidget);
  });

  testWidgets('cancel leaves the sheet open and deletes nothing',
      (WidgetTester tester) async {
    await _openSheet(tester, deleteFromServerSong: _withPath);

    await tester.tap(find.byKey(_deleteKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(_StubLibraryDelete.serverCalls, 0);
    expect(find.byKey(_deleteKey), findsOneWidget);
  });
}
