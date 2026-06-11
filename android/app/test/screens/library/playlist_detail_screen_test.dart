import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/playlist.dart';
import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/providers/library/library_playlist.dart';
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
}
