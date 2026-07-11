import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/album.dart';
import 'package:heerr/models/subsonic/playlist.dart';
import 'package:heerr/providers/library/library_filters.dart';

void main() {
  group('sort state providers (X2)', () {
    test('defaults: recentlyAdded / aToZ / recentlyAdded / not downloaded',
        () {
      final ProviderContainer c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(albumSortNotifierProvider), AlbumSort.recentlyAdded);
      expect(c.read(artistSortNotifierProvider), ArtistSort.aToZ);
      expect(
          c.read(playlistSortNotifierProvider), PlaylistSort.recentlyAdded);
      for (final LibraryTab tab in LibraryTab.values) {
        expect(c.read(downloadedOnlyNotifierProvider(tab)), isFalse);
      }
    });

    test('set + toggle transitions', () {
      final ProviderContainer c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(albumSortNotifierProvider.notifier).set(AlbumSort.year);
      expect(c.read(albumSortNotifierProvider), AlbumSort.year);

      c
          .read(downloadedOnlyNotifierProvider(LibraryTab.albums).notifier)
          .toggle();
      expect(
          c.read(downloadedOnlyNotifierProvider(LibraryTab.albums)), isTrue);
      // Other tabs unaffected — family keys are independent.
      expect(c.read(downloadedOnlyNotifierProvider(LibraryTab.artists)),
          isFalse);
    });
  });

  group('sortAlbums', () {
    const Album a2020 = Album(
        id: 'a', name: 'Alpha', year: 2020, created: '2026-01-01T00:00:00');
    const Album b2022 = Album(
        id: 'b', name: 'beta', year: 2022, created: '2026-03-01T00:00:00');
    const Album cNull = Album(id: 'c', name: 'Coda');

    test('recentlyAdded: created desc, null created last', () {
      final List<Album> out =
          sortAlbums(const <Album>[a2020, cNull, b2022], AlbumSort.recentlyAdded);
      expect(out.map((Album a) => a.id), <String>['b', 'a', 'c']);
    });

    test('alphabetical: case-insensitive name', () {
      final List<Album> out = sortAlbums(
          const <Album>[cNull, b2022, a2020], AlbumSort.alphabetical);
      expect(out.map((Album a) => a.name), <String>['Alpha', 'beta', 'Coda']);
    });

    test('year: desc, null year last', () {
      final List<Album> out =
          sortAlbums(const <Album>[a2020, cNull, b2022], AlbumSort.year);
      expect(out.map((Album a) => a.id), <String>['b', 'a', 'c']);
    });

    test('does not mutate the input list', () {
      final List<Album> input = <Album>[b2022, a2020];
      sortAlbums(input, AlbumSort.alphabetical);
      expect(input.first.id, 'b');
    });
  });

  group('sortPlaylists', () {
    const Playlist p1 = Playlist(
        id: '1', name: 'Old', created: '2026-01-01T00:00:00');
    const Playlist p2 = Playlist(
        id: '2',
        name: 'Edited',
        created: '2025-12-01T00:00:00',
        changed: '2026-06-01T00:00:00');
    const Playlist p3 = Playlist(id: '3', name: 'Bare');

    test('recentlyAdded: changed beats created, nulls last', () {
      final List<Playlist> out = sortPlaylists(
          const <Playlist>[p1, p3, p2], PlaylistSort.recentlyAdded);
      expect(out.map((Playlist p) => p.id), <String>['2', '1', '3']);
    });

    test('alphabetical by name', () {
      final List<Playlist> out = sortPlaylists(
          const <Playlist>[p1, p2, p3], PlaylistSort.alphabetical);
      expect(out.map((Playlist p) => p.name),
          <String>['Bare', 'Edited', 'Old']);
    });
  });
}
