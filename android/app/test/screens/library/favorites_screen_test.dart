import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/playlist.dart';
import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/providers/library/favourites.dart';
import 'package:heerr/providers/library/library_playlist.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/screens/library/favorites_screen.dart';
import 'package:heerr/theme.dart';
import 'package:heerr/widgets/song_row_actions.dart';

import '../../support/cred_test_support.dart';

class _NoopStorage implements SecureStorage {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

Song _song(int i) => Song(id: 's-$i', title: 'Song $i', artist: 'Artist $i');

Playlist _favPlaylist({List<Song> entry = const <Song>[]}) => Playlist(
      id: 'fav-1',
      name: kFavouritesPlaylistName,
      owner: 'alice',
      entry: entry,
    );

Widget _wrap({required List<Override> overrides}) {
  return ProviderScope(
    overrides: <Override>[
      secureStorageProvider.overrideWithValue(_NoopStorage()),
      ...overrides,
    ],
    child: MaterialApp(
      theme: heerrDarkTheme(),
      home: const FavoritesScreen(),
    ),
  );
}

void main() {
  initPrefsMock();

  testWidgets(
      'resolves the Favourites playlist and delegates to PlaylistDetailScreen',
      (WidgetTester tester) async {
    final Playlist fav = _favPlaylist(entry: List<Song>.generate(3, _song));
    await tester.pumpWidget(_wrap(overrides: <Override>[
      favouritesPlaylistProvider.overrideWith((_) async => fav),
      libraryPlaylistProvider(fav.id).overrideWith((_) async => fav),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Song 0'), findsOneWidget);
    expect(find.text('Artist 0'), findsOneWidget);
    expect(find.byType(SongRowActions), findsNWidgets(3));
  });

  testWidgets('no Favourites playlist yet renders the empty state',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(overrides: <Override>[
      favouritesPlaylistProvider.overrideWith((_) async => null),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Favorites'), findsOneWidget); // AppBar
    expect(find.text('No favorites yet'), findsOneWidget);
    expect(find.text('Heart songs to collect them here.'), findsOneWidget);
  });

  testWidgets('error state shows Retry which re-fetches',
      (WidgetTester tester) async {
    int fetches = 0;
    await tester.pumpWidget(_wrap(overrides: <Override>[
      favouritesPlaylistProvider.overrideWith((_) async {
        fetches++;
        throw Exception('net');
      }),
    ]));
    await tester.pumpAndSettle();
    expect(fetches, 1);
    expect(find.byKey(const Key('favorites-retry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('favorites-retry')));
    await tester.pumpAndSettle();
    expect(fetches, greaterThanOrEqualTo(2));
  });

  testWidgets('pull-to-refresh invalidates the provider (empty-state path)',
      (WidgetTester tester) async {
    int fetches = 0;
    await tester.pumpWidget(_wrap(overrides: <Override>[
      favouritesPlaylistProvider.overrideWith((_) async {
        fetches++;
        return null;
      }),
    ]));
    await tester.pumpAndSettle();
    expect(fetches, 1);

    final RefreshIndicator indicator =
        tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
    await indicator.onRefresh();
    await tester.pumpAndSettle();
    expect(fetches, greaterThanOrEqualTo(2));
  });
}
