import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/album.dart';
import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/offline/offline_paths.dart';
import 'package:heerr/providers/downloaded_songs.dart';
import 'package:heerr/providers/library/library_albums.dart';
import 'package:heerr/providers/library/library_edit.dart';
import 'package:heerr/services/backend_service.dart';

import '../../support/cred_test_support.dart';

// Y1 (#44): LibraryEdit notifier — service call + read-provider refresh +
// cover-cache eviction.

class _StubBackendService extends BackendService {
  _StubBackendService() : super(Dio());

  int editCalls = 0;
  String? lastPath;
  String? lastTitle;
  Uint8List? lastCover;
  Object? throwOnEdit;

  @override
  Future<void> editLibrarySong({
    required String path,
    String? title,
    String? album,
    String? artist,
    Uint8List? coverBytes,
  }) async {
    editCalls++;
    lastPath = path;
    lastTitle = title;
    lastCover = coverBytes;
    final Object? e = throwOnEdit;
    if (e != null) throw e;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const Song song = Song(
    id: 's1',
    title: 'Track',
    albumId: 'al1',
    coverArt: 'cover-1',
    path: 'Artist/Album/01 - Track.mp3',
  );

  late _StubBackendService stub;
  late int albumsFetches;
  late int downloadedFetches;
  late Directory tmp;
  late ProviderContainer container;

  setUp(() {
    stub = _StubBackendService();
    albumsFetches = 0;
    downloadedFetches = 0;
    tmp = Directory.systemTemp.createTempSync('heerr_edit_test');
    container = ProviderContainer(
      overrides: <Override>[
        backendServiceProvider.overrideWith((_) => Future.value(stub)),
        activeProfileOverride(),
        applicationDocumentsDirectoryProvider.overrideWith((_) async => tmp),
        libraryAlbumsProvider.overrideWith((_) async {
          albumsFetches++;
          return <Album>[];
        }),
        downloadedSongsProvider.overrideWith((_) async {
          downloadedFetches++;
          return <Song>[];
        }),
      ],
    );
    addTearDown(() {
      container.dispose();
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });
  });

  test('editSong sends the path + changed fields to the backend', () async {
    await container.read(libraryEditProvider.notifier).editSong(
          song,
          title: 'Corrected',
        );
    expect(stub.editCalls, 1);
    expect(stub.lastPath, 'Artist/Album/01 - Track.mp3');
    expect(stub.lastTitle, 'Corrected');
  });

  test('success invalidates library + downloads read providers', () async {
    await container.read(libraryAlbumsProvider.future);
    await container.read(downloadedSongsProvider.future);
    expect(albumsFetches, 1);
    expect(downloadedFetches, 1);

    await container
        .read(libraryEditProvider.notifier)
        .editSong(song, title: 'Corrected');

    await container.read(libraryAlbumsProvider.future);
    await container.read(downloadedSongsProvider.future);
    expect(albumsFetches, 2);
    expect(downloadedFetches, 2);
  });

  test('song without a path throws StateError and never hits the network',
      () async {
    const Song noPath = Song(id: 's2', title: 'No Path');
    await expectLater(
      container
          .read(libraryEditProvider.notifier)
          .editSong(noPath, title: 'x'),
      throwsStateError,
    );
    expect(stub.editCalls, 0);
  });

  test('editSong with nothing to change throws StateError', () async {
    await expectLater(
      container.read(libraryEditProvider.notifier).editSong(song),
      throwsStateError,
    );
    expect(stub.editCalls, 0);
  });

  test('backend failure rethrows and skips invalidation', () async {
    await container.read(libraryAlbumsProvider.future);
    stub.throwOnEdit = Exception('boom');

    await expectLater(
      container.read(libraryEditProvider.notifier).editSong(song, title: 'x'),
      throwsException,
    );

    await container.read(libraryAlbumsProvider.future);
    expect(albumsFetches, 1); // no refetch — invalidation never ran
  });

  test('cover upload evicts the cached cover file for the coverArt id',
      () async {
    final OfflinePaths paths = await container.read(offlinePathsProvider.future);
    final File coverFile = paths.coverFile(testCreds(), 'cover-1')!;
    coverFile.parent.createSync(recursive: true);
    coverFile.writeAsBytesSync(<int>[1, 2, 3]);
    expect(coverFile.existsSync(), isTrue);

    await container.read(libraryEditProvider.notifier).editSong(
          song,
          coverBytes: Uint8List.fromList(<int>[0xff, 0xd8, 0xff]),
        );

    expect(coverFile.existsSync(), isFalse);
    expect(stub.lastCover, isNotNull);
  });

  test('tags-only edit leaves the cached cover file untouched', () async {
    final OfflinePaths paths = await container.read(offlinePathsProvider.future);
    final File coverFile = paths.coverFile(testCreds(), 'cover-1')!;
    coverFile.parent.createSync(recursive: true);
    coverFile.writeAsBytesSync(<int>[1, 2, 3]);

    await container
        .read(libraryEditProvider.notifier)
        .editSong(song, title: 'Just the title');

    expect(coverFile.existsSync(), isTrue);
  });
}
