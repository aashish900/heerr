import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/album.dart';
import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/providers/downloaded_songs.dart';
import 'package:heerr/providers/library/library_albums.dart';
import 'package:heerr/providers/library/library_delete.dart';
import 'package:heerr/services/backend_service.dart';

// W1 (#41): LibraryDelete notifier — service call + read-provider refresh.

class _StubBackendService extends BackendService {
  _StubBackendService() : super(Dio());

  int deleteCalls = 0;
  String? lastPath;
  Object? throwOnDelete;

  @override
  Future<void> deleteLibrarySong(String path) async {
    deleteCalls++;
    lastPath = path;
    final Object? e = throwOnDelete;
    if (e != null) throw e;
  }
}

void main() {
  const Song song = Song(
    id: 's1',
    title: 'Track',
    albumId: 'al1',
    path: 'Artist/Album/01 - Track.mp3',
  );

  late _StubBackendService stub;
  late int albumsFetches;
  late int downloadedFetches;
  late ProviderContainer container;

  setUp(() {
    stub = _StubBackendService();
    albumsFetches = 0;
    downloadedFetches = 0;
    container = ProviderContainer(
      overrides: <Override>[
        backendServiceProvider.overrideWith((_) => Future.value(stub)),
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
    addTearDown(container.dispose);
  });

  test('deleteFromServer calls the backend with the subsonic path', () async {
    await container
        .read(libraryDeleteProvider.notifier)
        .deleteFromServer(song);
    expect(stub.deleteCalls, 1);
    expect(stub.lastPath, 'Artist/Album/01 - Track.mp3');
  });

  test('success invalidates library + downloads read providers', () async {
    // prime both providers so invalidation forces a refetch on next read
    await container.read(libraryAlbumsProvider.future);
    await container.read(downloadedSongsProvider.future);
    expect(albumsFetches, 1);
    expect(downloadedFetches, 1);

    await container
        .read(libraryDeleteProvider.notifier)
        .deleteFromServer(song);

    await container.read(libraryAlbumsProvider.future);
    await container.read(downloadedSongsProvider.future);
    expect(albumsFetches, 2);
    expect(downloadedFetches, 2);
  });

  test('song without a path throws StateError and never hits the network',
      () async {
    const Song noPath = Song(id: 's2', title: 'No Path');
    await expectLater(
      container.read(libraryDeleteProvider.notifier).deleteFromServer(noPath),
      throwsStateError,
    );
    expect(stub.deleteCalls, 0);
  });

  test('backend failure rethrows and skips invalidation', () async {
    await container.read(libraryAlbumsProvider.future);
    stub.throwOnDelete = Exception('boom');

    await expectLater(
      container.read(libraryDeleteProvider.notifier).deleteFromServer(song),
      throwsException,
    );

    await container.read(libraryAlbumsProvider.future);
    expect(albumsFetches, 1); // no refetch — invalidation never ran
  });
}
