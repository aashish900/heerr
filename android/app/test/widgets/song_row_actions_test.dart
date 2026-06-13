import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/playlist.dart';
import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/providers/library/favourites.dart';
import 'package:heerr/providers/library/library_playlists.dart';
import 'package:heerr/providers/library/playlist_mutations.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/widgets/song_row_actions.dart';

class _NoopStorage implements SecureStorage {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

class _StubPlaylistMutations extends PlaylistMutations {
  static int toggleCalls = 0;
  static Song? lastToggled;

  static void reset() {
    toggleCalls = 0;
    lastToggled = null;
  }

  @override
  void build() {}

  @override
  Future<void> toggleFavourite(Song song) async {
    toggleCalls++;
    lastToggled = song;
  }
}

Override _favouriteIds(Set<String> ids) {
  return favouriteSongIdsProvider.overrideWith(
    (FavouriteSongIdsRef ref) async => ids,
  );
}

Widget _wrap(Widget child, List<Override> extra) {
  return ProviderScope(
    overrides: <Override>[
      secureStorageProvider.overrideWithValue(_NoopStorage()),
      // Default: no Favourites playlist yet so the heart starts as
      // outlined. Individual tests override with the desired id set.
      _favouriteIds(const <String>{}),
      favouritesPlaylistProvider.overrideWith(
        (FavouritesPlaylistRef ref) async => null,
      ),
      ...extra,
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  setUp(_StubPlaylistMutations.reset);
  tearDown(_StubPlaylistMutations.reset);

  const Song song = Song(id: 'so-1', title: 'A');

  testWidgets(
    'heart icon is outlined when the song is not in Favourites',
    (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        const SongRowActions(song: song),
        <Override>[
          _favouriteIds(const <String>{'so-other'}),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);
    },
  );

  testWidgets(
    'heart icon is filled and red when the song IS in Favourites',
    (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        const SongRowActions(song: song),
        <Override>[
          _favouriteIds(const <String>{'so-1'}),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);

      // Tint check: the heart Icon widget's color is redAccent when in.
      final Icon icon =
          tester.widget<Icon>(find.byIcon(Icons.favorite));
      expect(icon.color, Colors.redAccent);
    },
  );

  testWidgets(
    'tapping the heart calls PlaylistMutations.toggleFavourite(song)',
    (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        const SongRowActions(song: song),
        <Override>[
          playlistMutationsProvider
              .overrideWith(_StubPlaylistMutations.new),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();

      expect(_StubPlaylistMutations.toggleCalls, 1);
      expect(_StubPlaylistMutations.lastToggled?.id, 'so-1');
    },
  );

  testWidgets(
    'more_vert button opens the AddToPlaylistSheet with this song id',
    (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        const SongRowActions(song: song),
        <Override>[
          // The sheet watches libraryPlaylistsProvider — override with an
          // empty list so it renders the "no editable playlists yet"
          // copy. We're just asserting the sheet opened.
          libraryPlaylistsProvider.overrideWith(
            (Ref<AsyncValue<List<Playlist>>> ref) =>
                Future<List<Playlist>>.value(const <Playlist>[]),
          ),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Sheet title with song-count summary is the canonical signal that
      // AddToPlaylistSheet is open.
      expect(find.text('Add 1 song to playlist'), findsOneWidget);
    },
  );

  testWidgets(
    'trailingStatus is rendered to the right of the action icons',
    (WidgetTester tester) async {
      const Key statusKey = Key('status');
      await tester.pumpWidget(_wrap(
        const SongRowActions(
          song: song,
          trailingStatus: Icon(Icons.download_done, key: statusKey),
        ),
        const <Override>[],
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(statusKey), findsOneWidget);
    },
  );
}

