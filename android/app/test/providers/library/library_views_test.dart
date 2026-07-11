import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/album.dart';
import 'package:heerr/offline/offline_manifest.dart';
import 'package:heerr/providers/library/library_albums.dart';
import 'package:heerr/providers/library/library_filters.dart';
import 'package:heerr/providers/library/library_views.dart';

const Album _old = Album(
    id: 'old', name: 'Zebra', year: 2010, created: '2020-01-01T00:00:00');
const Album _new = Album(
    id: 'new', name: 'Apple', year: 2024, created: '2026-06-01T00:00:00');
const Album _mid = Album(
    id: 'mid', name: 'Mango', year: 2018, created: '2023-01-01T00:00:00');

ProviderContainer _container({OfflineManifest? manifest}) {
  return ProviderContainer(
    overrides: <Override>[
      libraryAlbumsProvider.overrideWith(
        (Ref<AsyncValue<List<Album>>> ref) async =>
            const <Album>[_old, _new, _mid],
      ),
      if (manifest != null)
        offlineManifestProvider.overrideWith(
          (OfflineManifestRef ref) async => manifest,
        ),
    ],
  );
}

void main() {
  group('sortedLibraryAlbums (X3)', () {
    test('default: recently added first', () async {
      final ProviderContainer c = _container();
      addTearDown(c.dispose);
      final List<Album> out =
          await c.read(sortedLibraryAlbumsProvider.future);
      expect(out.map((Album a) => a.id), <String>['new', 'mid', 'old']);
    });

    test('switching sort re-derives the list', () async {
      final ProviderContainer c = _container();
      addTearDown(c.dispose);
      c.read(albumSortNotifierProvider.notifier).set(AlbumSort.alphabetical);
      final List<Album> out =
          await c.read(sortedLibraryAlbumsProvider.future);
      expect(out.map((Album a) => a.name),
          <String>['Apple', 'Mango', 'Zebra']);
    });

    test('downloadedOnly keeps only manifest-marked albums', () async {
      final ProviderContainer c = _container(
        manifest:
            const OfflineManifest(markedAlbums: <String>{'mid'}),
      );
      addTearDown(c.dispose);
      c
          .read(downloadedOnlyNotifierProvider(LibraryTab.albums).notifier)
          .toggle();
      final List<Album> out =
          await c.read(sortedLibraryAlbumsProvider.future);
      expect(out.map((Album a) => a.id), <String>['mid']);
    });
  });
}
