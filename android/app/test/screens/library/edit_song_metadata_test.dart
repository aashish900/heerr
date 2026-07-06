import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/offline/offline_paths.dart';
import 'package:heerr/providers/library/library_edit.dart';
import 'package:heerr/providers/library/song_cover_image_picker.dart';
import 'package:heerr/screens/library/edit_song_metadata_screen.dart';

import '../../support/cred_test_support.dart';

// Y2 (#44): edit-metadata screen — prefill, changed-fields-only save, pop.

class _StubLibraryEdit extends LibraryEdit {
  static int calls = 0;
  static String? lastTitle;
  static String? lastAlbum;
  static String? lastArtist;
  static Uint8List? lastCover;

  static void reset() {
    calls = 0;
    lastTitle = null;
    lastAlbum = null;
    lastArtist = null;
    lastCover = null;
  }

  @override
  void build() {}

  @override
  Future<void> editSong(
    Song song, {
    String? title,
    String? album,
    String? artist,
    Uint8List? coverBytes,
  }) async {
    calls++;
    lastTitle = title;
    lastAlbum = album;
    lastArtist = artist;
    lastCover = coverBytes;
  }
}

const Song _song = Song(
  id: 's1',
  title: 'Wrong Title',
  album: 'Wrong Album',
  artist: 'Wrong Artist',
  coverArt: 'cover-1',
  path: 'Artist/Album/01 - Track.mp3',
);

const Key _saveKey = Key('edit-song-save');
const Key _titleKey = Key('edit-song-title');
const Key _artistKey = Key('edit-song-artist');
const Key _coverPickerKey = Key('edit-song-cover-picker');

Future<void> _pump(
  WidgetTester tester, {
  Uint8List? pickReturns,
}) async {
  final Directory tmp = Directory.systemTemp.createTempSync('heerr_edit_ui');
  addTearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        activeProfileOverride(),
        applicationDocumentsDirectoryProvider.overrideWith((_) async => tmp),
        libraryEditProvider.overrideWith(_StubLibraryEdit.new),
        songCoverImagePickerProvider
            .overrideWithValue(() async => pickReturns),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const EditSongMetadataScreen(song: _song),
                  ),
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
  setUp(_StubLibraryEdit.reset);

  testWidgets('prefills the fields from the song', (WidgetTester tester) async {
    await _pump(tester);
    expect(find.widgetWithText(TextField, 'Wrong Title'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Wrong Album'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Wrong Artist'), findsOneWidget);
  });

  testWidgets('Save is disabled until something changes',
      (WidgetTester tester) async {
    await _pump(tester);
    TextButton save() => tester.widget<TextButton>(find.byKey(_saveKey));
    expect(save().onPressed, isNull);

    await tester.enterText(find.byKey(_titleKey), 'Correct Title');
    await tester.pump();
    expect(save().onPressed, isNotNull);
  });

  testWidgets('Save sends only the changed fields', (WidgetTester tester) async {
    await _pump(tester);
    await tester.enterText(find.byKey(_titleKey), 'Correct Title');
    await tester.pump();

    await tester.tap(find.byKey(_saveKey));
    await tester.pumpAndSettle();

    expect(_StubLibraryEdit.calls, 1);
    expect(_StubLibraryEdit.lastTitle, 'Correct Title');
    expect(_StubLibraryEdit.lastAlbum, isNull);
    expect(_StubLibraryEdit.lastArtist, isNull);
    expect(_StubLibraryEdit.lastCover, isNull);
  });

  testWidgets('re-entering the original value is not a change',
      (WidgetTester tester) async {
    await _pump(tester);
    await tester.enterText(find.byKey(_titleKey), 'Wrong Title');
    await tester.pump();
    expect(
      tester.widget<TextButton>(find.byKey(_saveKey)).onPressed,
      isNull,
    );
  });

  testWidgets('picking a cover enables Save and sends the bytes',
      (WidgetTester tester) async {
    final Uint8List bytes = Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0x00]);
    await _pump(tester, pickReturns: bytes);

    await tester.tap(find.byKey(_coverPickerKey));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextButton>(find.byKey(_saveKey)).onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(_saveKey));
    await tester.pumpAndSettle();
    expect(_StubLibraryEdit.lastCover, bytes);
  });

  testWidgets('successful save pops the screen and shows a snackbar',
      (WidgetTester tester) async {
    await _pump(tester);
    await tester.enterText(find.byKey(_artistKey), 'Real Artist');
    await tester.pump();

    await tester.tap(find.byKey(_saveKey));
    await tester.pumpAndSettle();

    // screen popped — the launcher button is visible again
    expect(find.byKey(_saveKey), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(find.textContaining('Updated'), findsOneWidget);
    expect(_StubLibraryEdit.lastArtist, 'Real Artist');
  });
}
