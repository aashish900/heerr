import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/search_result_item.dart';
import 'package:heerr/models/subsonic/playlist.dart';
import 'package:heerr/providers/library/library_playlists.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/widgets/download_options_sheet.dart';

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

const SearchResultItem _item = SearchResultItem(
  sourceUrl: 'https://music.youtube.com/watch?v=abc',
  sourceType: 'song',
  title: 'Test Song',
  artist: 'Test Artist',
  alreadyDownloaded: false,
);

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

/// Mount a host button that opens the sheet via `DownloadOptionsSheet.show`.
/// [onDownloadOnly] / [onDownloadToPlaylist] are forwarded so tests can assert
/// the callbacks fire. When [settle] is false the caller drives the pump (for
/// the never-resolving loading state).
Future<void> _openSheet(
  WidgetTester tester, {
  required List<Override> overrides,
  VoidCallback? onDownloadOnly,
  void Function(String, String)? onDownloadToPlaylist,
  String? username = 'phone',
  bool settle = true,
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
                onPressed: () => DownloadOptionsSheet.show(
                  context: context,
                  item: _item,
                  onDownloadOnly: onDownloadOnly ?? () {},
                  onDownloadToPlaylist:
                      onDownloadToPlaylist ?? (String _, String _) {},
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
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  initPrefsMock();

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

  testWidgets('renders the song title', (WidgetTester tester) async {
    await _openSheet(
      tester,
      overrides: <Override>[
        _playlistsValue(const AsyncData<List<Playlist>>(<Playlist>[owned1])),
      ],
    );
    expect(find.text('Test Song'), findsOneWidget);
  });

  testWidgets('lists only playlists owned by the active user',
      (WidgetTester tester) async {
    await _openSheet(
      tester,
      overrides: <Override>[
        _playlistsValue(const AsyncData<List<Playlist>>(<Playlist>[
          owned1,
          someoneElses,
          owned2,
        ])),
      ],
    );
    expect(find.text('Morning'), findsOneWidget);
    expect(find.text('Workout'), findsOneWidget);
    expect(find.text('Shared mix'), findsNothing);
  });

  testWidgets('no owned playlists → empty-state copy',
      (WidgetTester tester) async {
    await _openSheet(
      tester,
      overrides: <Override>[
        _playlistsValue(const AsyncData<List<Playlist>>(<Playlist>[
          someoneElses,
        ])),
      ],
    );
    expect(find.text('No playlists yet.'), findsOneWidget);
    // "Download" row is still present regardless of playlist availability.
    expect(
      find.byKey(const Key('download-options-download-only')),
      findsOneWidget,
    );
  });

  testWidgets('tap "Download" fires onDownloadOnly and closes the sheet',
      (WidgetTester tester) async {
    int calls = 0;
    await _openSheet(
      tester,
      overrides: <Override>[
        _playlistsValue(const AsyncData<List<Playlist>>(<Playlist>[owned1])),
      ],
      onDownloadOnly: () => calls++,
    );

    await tester.tap(find.byKey(const Key('download-options-download-only')));
    await tester.pumpAndSettle();

    expect(calls, 1);
    // Sheet gone.
    expect(find.text('Add to playlist after download'), findsNothing);
  });

  testWidgets(
      'tap a playlist row fires onDownloadToPlaylist with id+name and closes',
      (WidgetTester tester) async {
    String? gotId;
    String? gotName;
    await _openSheet(
      tester,
      overrides: <Override>[
        _playlistsValue(const AsyncData<List<Playlist>>(<Playlist>[owned1])),
      ],
      onDownloadToPlaylist: (String id, String name) {
        gotId = id;
        gotName = name;
      },
    );

    await tester.tap(find.byKey(const Key('download-to-playlist-pl-owned-1')));
    await tester.pumpAndSettle();

    expect(gotId, 'pl-owned-1');
    expect(gotName, 'Morning');
    expect(find.text('Add to playlist after download'), findsNothing);
  });

  testWidgets('loading playlists → spinner', (WidgetTester tester) async {
    await _openSheet(
      tester,
      overrides: <Override>[
        _playlistsValue(const AsyncLoading<List<Playlist>>()),
      ],
      settle: false,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
