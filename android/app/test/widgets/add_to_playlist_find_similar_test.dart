import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/seed_track.dart';
import 'package:heerr/models/subsonic/playlist.dart';
import 'package:heerr/providers/library/library_playlists.dart';
import 'package:heerr/providers/recommendations.dart';
import 'package:heerr/widgets/add_to_playlist_sheet.dart';

Override _emptyPlaylists() =>
    libraryPlaylistsProvider.overrideWith(
      (Ref<AsyncValue<List<Playlist>>> _) async => const <Playlist>[],
    );

Future<void> _openSheet(
  WidgetTester tester, {
  required SeedTrack? findSimilarSeed,
  required ProviderContainer container,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => AddToPlaylistSheet.show(
                  context: context,
                  songIds: const <String>['song-1'],
                  findSimilarSeed: findSimilarSeed,
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
  testWidgets(
      'Find similar entry renders when findSimilarSeed is non-null',
      (WidgetTester tester) async {
    final ProviderContainer c = ProviderContainer(overrides: <Override>[
      _emptyPlaylists(),
    ]);
    addTearDown(c.dispose);

    await _openSheet(
      tester,
      container: c,
      findSimilarSeed: const SeedTrack(title: 'T', artist: 'A'),
    );
    expect(
      find.byKey(const Key('add-to-playlist-find-similar')),
      findsOneWidget,
    );
    expect(find.text('Find similar →'), findsOneWidget);
  });

  testWidgets(
      'Find similar entry is hidden when findSimilarSeed is null',
      (WidgetTester tester) async {
    final ProviderContainer c = ProviderContainer(overrides: <Override>[
      _emptyPlaylists(),
    ]);
    addTearDown(c.dispose);

    await _openSheet(tester, container: c, findSimilarSeed: null);
    expect(
      find.byKey(const Key('add-to-playlist-find-similar')),
      findsNothing,
    );
  });

  testWidgets(
      'Tapping Find similar sets manualSeedProvider to the passed seed',
      (WidgetTester tester) async {
    final ProviderContainer c = ProviderContainer(overrides: <Override>[
      _emptyPlaylists(),
    ]);
    addTearDown(c.dispose);

    await _openSheet(
      tester,
      container: c,
      findSimilarSeed: const SeedTrack(title: 'TheTitle', artist: 'TheArtist'),
    );

    // The "Find similar" tile lives at the top of the sheet; tap by key
    // so the test isn't sensitive to surrounding-tile order.
    await tester.tap(find.byKey(const Key('add-to-playlist-find-similar')));
    await tester.pumpAndSettle();

    final SeedTrack? seed = c.read(manualSeedProvider);
    expect(seed, isNotNull);
    expect(seed!.title, 'TheTitle');
    expect(seed.artist, 'TheArtist');
  });
}
