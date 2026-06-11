import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/album.dart';
import 'package:heerr/models/subsonic/artist.dart';
import 'package:heerr/providers/library/library_artist.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/screens/library/artist_detail_screen.dart';
import 'package:heerr/widgets/empty_state.dart';
import 'package:heerr/widgets/library_result_tile.dart';
import 'package:heerr/widgets/skeleton.dart';

class _NoopStorage implements SecureStorage {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

Override _artistValue(String id, AsyncValue<Artist> value) {
  return libraryArtistProvider(id).overrideWith(
    (Ref<AsyncValue<Artist>> ref) {
      return value.when(
        data: (Artist a) => Future<Artist>.value(a),
        loading: () => Completer<Artist>().future,
        error: (Object e, StackTrace st) => Future<Artist>.error(e, st),
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
    child: MaterialApp(home: ArtistDetailScreen(artistId: id)),
  );
}

void main() {
  testWidgets('loading → SkeletonList', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap('ar-1', <Override>[
      _artistValue('ar-1', const AsyncLoading<Artist>()),
    ]));
    await tester.pump();
    expect(find.byType(SkeletonList), findsOneWidget);
  });

  testWidgets('empty (no albums) → EmptyState "No albums"',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap('ar-1', <Override>[
      _artistValue(
        'ar-1',
        const AsyncData<Artist>(
          Artist(id: 'ar-1', name: 'Tame Impala'),
        ),
      ),
    ]));
    await tester.pumpAndSettle();
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No albums'), findsOneWidget);
  });

  testWidgets('data → renders album tiles + AppBar shows artist name',
      (WidgetTester tester) async {
    const Artist a = Artist(
      id: 'ar-1',
      name: 'Tame Impala',
      album: <Album>[
        Album(
          id: 'al-1',
          name: 'Currents',
          artist: 'Tame Impala',
          year: 2015,
        ),
        Album(
          id: 'al-2',
          name: 'Lonerism',
          artist: 'Tame Impala',
          year: 2012,
        ),
      ],
    );
    await tester.pumpWidget(_wrap('ar-1', <Override>[
      _artistValue('ar-1', const AsyncData<Artist>(a)),
    ]));
    await tester.pumpAndSettle();

    final AppBar bar = tester.widget<AppBar>(find.byType(AppBar));
    expect((bar.title! as Text).data, 'Tame Impala');
    expect(find.text('Currents'), findsOneWidget);
    expect(find.text('Lonerism'), findsOneWidget);
    expect(find.text('2015'), findsOneWidget);
    expect(find.byType(LibraryResultTile), findsNWidgets(2));
  });

  testWidgets('error → renders error message',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap('ar-1', <Override>[
      _artistValue('ar-1', const AsyncError<Artist>('boom', StackTrace.empty)),
    ]));
    await tester.pumpAndSettle();
    expect(find.textContaining('Error'), findsOneWidget);
  });
}
