import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/playlist.dart';
import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/offline/offline_paths.dart';
import 'package:heerr/providers/library/library_playlists.dart';
import 'package:heerr/screens/library/edit_song_metadata_screen.dart';
import 'package:heerr/widgets/add_to_playlist_sheet.dart';

import '../support/cred_test_support.dart';

// Y2 (#44): "Edit metadata…" tile in the add-to-playlist sheet.

const Key _editKey = Key('add-to-playlist-edit-metadata');

const Song _withPath = Song(
  id: 's1',
  title: 'Pathful',
  path: 'Artist/Album/01 - Pathful.mp3',
);

const Song _noPath = Song(id: 's2', title: 'Pathless');

Future<void> _openSheet(
  WidgetTester tester, {
  Song? editMetadataSong,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        activeProfileOverride(),
        applicationDocumentsDirectoryProvider.overrideWith(
          (_) async => Directory.systemTemp,
        ),
        libraryPlaylistsProvider.overrideWith(
          (Ref<AsyncValue<List<Playlist>>> ref) =>
              Future<List<Playlist>>.value(<Playlist>[]),
        ),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => AddToPlaylistSheet.show(
                  context: context,
                  songIds: <String>[
                    if (editMetadataSong != null) editMetadataSong.id,
                  ],
                  editMetadataSong: editMetadataSong,
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
  testWidgets('tile renders when the song has a server path',
      (WidgetTester tester) async {
    await _openSheet(tester, editMetadataSong: _withPath);
    expect(find.byKey(_editKey), findsOneWidget);
  });

  testWidgets('tile is absent when no song is passed',
      (WidgetTester tester) async {
    await _openSheet(tester);
    expect(find.byKey(_editKey), findsNothing);
  });

  testWidgets('tile is absent when the song has no path',
      (WidgetTester tester) async {
    await _openSheet(tester, editMetadataSong: _noPath);
    expect(find.byKey(_editKey), findsNothing);
  });

  testWidgets('tapping the tile closes the sheet and pushes the edit screen',
      (WidgetTester tester) async {
    await _openSheet(tester, editMetadataSong: _withPath);

    await tester.tap(find.byKey(_editKey));
    await tester.pumpAndSettle();

    expect(find.byKey(_editKey), findsNothing); // sheet popped
    expect(find.byType(EditSongMetadataScreen), findsOneWidget);
  });
}
