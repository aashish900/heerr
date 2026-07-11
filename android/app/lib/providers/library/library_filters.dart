import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/subsonic/album.dart';
import '../../models/subsonic/playlist.dart';

part 'library_filters.g.dart';

/// Which Library sub-tab a filter belongs to (X2, LIBRARYSCREEN.md §4).
/// Keys the per-tab `downloadedOnly` family so each tab toggles
/// independently.
enum LibraryTab { albums, artists, playlists }

/// Sort orders for the Albums tab. `recentlyAdded` is the mockup default.
enum AlbumSort { recentlyAdded, alphabetical, year }

/// Sort orders for the Artists tab.
enum ArtistSort { aToZ, zToA }

/// Sort orders for the Playlists tab.
enum PlaylistSort { recentlyAdded, alphabetical }

extension AlbumSortLabel on AlbumSort {
  String get label => switch (this) {
        AlbumSort.recentlyAdded => 'Recently Added',
        AlbumSort.alphabetical => 'A–Z',
        AlbumSort.year => 'Year',
      };
}

extension ArtistSortLabel on ArtistSort {
  String get label => switch (this) {
        ArtistSort.aToZ => 'A–Z',
        ArtistSort.zToA => 'Z–A',
      };
}

extension PlaylistSortLabel on PlaylistSort {
  String get label => switch (this) {
        PlaylistSort.recentlyAdded => 'Recently Added',
        PlaylistSort.alphabetical => 'A–Z',
      };
}

@riverpod
class AlbumSortNotifier extends _$AlbumSortNotifier {
  @override
  AlbumSort build() => AlbumSort.recentlyAdded;

  void set(AlbumSort value) => state = value;
}

@riverpod
class ArtistSortNotifier extends _$ArtistSortNotifier {
  @override
  ArtistSort build() => ArtistSort.aToZ;

  void set(ArtistSort value) => state = value;
}

@riverpod
class PlaylistSortNotifier extends _$PlaylistSortNotifier {
  @override
  PlaylistSort build() => PlaylistSort.recentlyAdded;

  void set(PlaylistSort value) => state = value;
}

/// Per-tab "Downloaded" toggle — filters each tab down to items marked for
/// offline in the manifest (X3/X5/X6 wire the actual filtering).
@riverpod
class DownloadedOnlyNotifier extends _$DownloadedOnlyNotifier {
  @override
  bool build(LibraryTab tab) => false;

  void toggle() => state = !state;
}

// ---------------------------------------------------------------------------
// Pure sort helpers — unit-testable, used by the derived tab providers.
// ---------------------------------------------------------------------------

int _byNameCi(String a, String b) =>
    a.toLowerCase().compareTo(b.toLowerCase());

/// Sorts a copy of [albums] per [sort]:
/// - `recentlyAdded`: `created` ISO-8601 string descending; null-created
///   albums sink to the end (string compare is safe for ISO-8601).
/// - `alphabetical`: case-insensitive name.
/// - `year`: year descending, null years last, ties by name.
List<Album> sortAlbums(List<Album> albums, AlbumSort sort) {
  final List<Album> out = List<Album>.of(albums);
  switch (sort) {
    case AlbumSort.recentlyAdded:
      out.sort((Album a, Album b) {
        final String? ca = a.created;
        final String? cb = b.created;
        if (ca == null && cb == null) return _byNameCi(a.name, b.name);
        if (ca == null) return 1;
        if (cb == null) return -1;
        return cb.compareTo(ca);
      });
    case AlbumSort.alphabetical:
      out.sort((Album a, Album b) => _byNameCi(a.name, b.name));
    case AlbumSort.year:
      out.sort((Album a, Album b) {
        final int? ya = a.year;
        final int? yb = b.year;
        if (ya == null && yb == null) return _byNameCi(a.name, b.name);
        if (ya == null) return 1;
        if (yb == null) return -1;
        final int cmp = yb.compareTo(ya);
        return cmp != 0 ? cmp : _byNameCi(a.name, b.name);
      });
  }
  return out;
}

/// Sorts a copy of [playlists] per [sort]. `recentlyAdded` prefers the
/// `changed` timestamp over `created` (a playlist edit bumps it in
/// Navidrome); both null → name order, nulls last.
List<Playlist> sortPlaylists(List<Playlist> playlists, PlaylistSort sort) {
  final List<Playlist> out = List<Playlist>.of(playlists);
  switch (sort) {
    case PlaylistSort.recentlyAdded:
      out.sort((Playlist a, Playlist b) {
        final String? ta = a.changed ?? a.created;
        final String? tb = b.changed ?? b.created;
        if (ta == null && tb == null) return _byNameCi(a.name, b.name);
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });
    case PlaylistSort.alphabetical:
      out.sort((Playlist a, Playlist b) => _byNameCi(a.name, b.name));
  }
  return out;
}
