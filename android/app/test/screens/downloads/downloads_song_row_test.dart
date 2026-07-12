import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/offline/offline_manifest.dart';
import 'package:heerr/offline/offline_sync.dart';
import 'package:heerr/providers/downloaded_songs.dart';
import 'package:heerr/providers/downloads_views.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/providers/server_status.dart';
import 'package:heerr/screens/downloads/downloads_screen.dart';

import '../../support/cred_test_support.dart';

// DL6: Songs-tab metadata line ("Lossless • Today • 1.0 KB") + kebab menu
// opening the existing W1 delete sheet.

class _NoopStorage implements SecureStorage {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

class _StaticServerStatus extends ServerStatusNotifier {
  @override
  Future<ServerStatus> build() async =>
      (online: false, errorMessage: null, checkedAt: DateTime.now());
}

class _StaticOfflineSync extends OfflineSync {
  @override
  Future<OfflineSyncStatus> build() async => (
        running: false,
        targetCount: 0,
        readyCount: 0,
        failedCount: 0,
        lastError: null,
        lastTickAt: null,
      );
}

void main() {
  testWidgets('metadata line shows lossless/day/size', (WidgetTester tester) async {
    final Song song = const Song(id: 's1', title: 'After Hours', artist: 'The Weeknd');
    final DownloadedSongRow row = (
      song: song,
      entry: OfflineSongEntry(
        state: OfflineSongState.ready,
        suffix: 'flac',
        downloadedAt: DateTime.now(),
        size: 1024,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          secureStorageProvider.overrideWithValue(_NoopStorage()),
          activeProfileOverride(),
          downloadedAlbumIdsProvider.overrideWith((_) async => <String>[]),
          downloadedSongsViewProvider.overrideWith((_) async => <DownloadedSongRow>[row]),
          serverStatusNotifierProvider.overrideWith(_StaticServerStatus.new),
          offlineSyncProvider.overrideWith(_StaticOfflineSync.new),
        ],
        child: const MaterialApp(home: DownloadsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Songs'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Lossless • Today • 1.0 KB'), findsOneWidget);
    expect(find.byKey(const Key('downloads-song-kebab')), findsOneWidget);
  });

  testWidgets('kebab tap opens the same delete sheet as long-press',
      (WidgetTester tester) async {
    final Song song = const Song(
      id: 's1',
      title: 'After Hours',
      artist: 'The Weeknd',
      path: 'W/A/01.mp3',
    );
    final DownloadedSongRow row = (
      song: song,
      entry: const OfflineSongEntry(state: OfflineSongState.ready),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          secureStorageProvider.overrideWithValue(_NoopStorage()),
          activeProfileOverride(),
          downloadedAlbumIdsProvider.overrideWith((_) async => <String>[]),
          downloadedSongsViewProvider.overrideWith((_) async => <DownloadedSongRow>[row]),
          serverStatusNotifierProvider.overrideWith(_StaticServerStatus.new),
          offlineSyncProvider.overrideWith(_StaticOfflineSync.new),
        ],
        child: const MaterialApp(home: DownloadsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Songs'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('downloads-song-kebab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('delete-song-device')), findsOneWidget);
    expect(find.byKey(const Key('delete-song-server')), findsOneWidget);
  });
}
