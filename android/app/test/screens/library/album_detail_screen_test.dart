import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/album.dart';
import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/providers/library/library_album.dart';
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
}
