import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/offline/offline_marker.dart';
import 'package:heerr/providers/downloaded_songs.dart';
import 'package:heerr/providers/library/library_delete.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/screens/downloads_screen.dart';

import '../support/cred_test_support.dart';

// W1 (#41): Downloads > Songs long-press → Device / Server / Both sheet.

class _NoopStorage implements SecureStorage {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

class _StubMarker extends OfflineMarker {
  static int deleteLocalCalls = 0;
  static String? lastSongId;

  static void reset() {
    deleteLocalCalls = 0;
    lastSongId = null;
  }

  @override
  Future<void> build() async {}

  @override
  Future<void> deleteSongLocally(String songId) async {
    deleteLocalCalls++;
    lastSongId = songId;
  }
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

const Song _withPath = Song(
  id: 's1',
  title: 'Pathful',
  artist: 'Artist',
  path: 'Artist/Album/01 - Pathful.mp3',
);

const Song _noPath = Song(id: 's2', title: 'Pathless', artist: 'Artist');

Future<void> _pumpSongsTab(WidgetTester tester, List<Song> songs) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        secureStorageProvider.overrideWithValue(_NoopStorage()),
        activeProfileOverride(),
        downloadedAlbumIdsProvider.overrideWith((_) async => <String>[]),
        downloadedSongsProvider.overrideWith((_) async => songs),
        offlineMarkerProvider.overrideWith(_StubMarker.new),
        libraryDeleteProvider.overrideWith(_StubLibraryDelete.new),
      ],
      child: const MaterialApp(home: DownloadsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Songs'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    _StubMarker.reset();
    _StubLibraryDelete.reset();
  });

  testWidgets('long-press opens the sheet with all three delete options',
      (WidgetTester tester) async {
    await _pumpSongsTab(tester, <Song>[_withPath]);

    await tester.longPress(find.text('Pathful'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('delete-song-device')), findsOneWidget);
    expect(find.byKey(const Key('delete-song-server')), findsOneWidget);
    expect(find.byKey(const Key('delete-song-both')), findsOneWidget);
  });

  testWidgets('server + both tiles are disabled when the song has no path',
      (WidgetTester tester) async {
    await _pumpSongsTab(tester, <Song>[_noPath]);

    await tester.longPress(find.text('Pathless'));
    await tester.pumpAndSettle();

    final ListTile server = tester
        .widget<ListTile>(find.byKey(const Key('delete-song-server')));
    final ListTile both =
        tester.widget<ListTile>(find.byKey(const Key('delete-song-both')));
    final ListTile device =
        tester.widget<ListTile>(find.byKey(const Key('delete-song-device')));
    expect(server.enabled, isFalse);
    expect(both.enabled, isFalse);
    expect(device.enabled, isTrue);
  });

  testWidgets('device option confirms then calls deleteSongLocally only',
      (WidgetTester tester) async {
    await _pumpSongsTab(tester, <Song>[_withPath]);

    await tester.longPress(find.text('Pathful'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-song-device')));
    await tester.pumpAndSettle();

    expect(find.text('Delete from device?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(_StubMarker.deleteLocalCalls, 1);
    expect(_StubMarker.lastSongId, 's1');
    expect(_StubLibraryDelete.serverCalls, 0);
    expect(find.textContaining('from device'), findsOneWidget);
  });

  testWidgets('server option confirms then calls deleteFromServer only',
      (WidgetTester tester) async {
    await _pumpSongsTab(tester, <Song>[_withPath]);

    await tester.longPress(find.text('Pathful'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-song-server')));
    await tester.pumpAndSettle();

    expect(find.text('Delete from server?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(_StubLibraryDelete.serverCalls, 1);
    expect(_StubLibraryDelete.lastSong?.id, 's1');
    expect(_StubMarker.deleteLocalCalls, 0);
    expect(find.textContaining('from server'), findsOneWidget);
  });

  testWidgets('both option calls local then server delete',
      (WidgetTester tester) async {
    await _pumpSongsTab(tester, <Song>[_withPath]);

    await tester.longPress(find.text('Pathful'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-song-both')));
    await tester.pumpAndSettle();

    expect(find.text('Delete from device and server?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(_StubMarker.deleteLocalCalls, 1);
    expect(_StubLibraryDelete.serverCalls, 1);
    expect(find.textContaining('device and server'), findsOneWidget);
  });

  testWidgets('cancelling the confirmation dialog deletes nothing',
      (WidgetTester tester) async {
    await _pumpSongsTab(tester, <Song>[_withPath]);

    await tester.longPress(find.text('Pathful'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-song-both')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(_StubMarker.deleteLocalCalls, 0);
    expect(_StubLibraryDelete.serverCalls, 0);
  });
}
