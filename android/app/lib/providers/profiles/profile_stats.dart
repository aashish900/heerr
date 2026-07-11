import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/subsonic/album.dart';
import '../../models/subsonic/artist_index.dart';
import '../../models/subsonic/playlist.dart';
import '../library/library_albums.dart';
import '../library/library_artists.dart';
import '../library/library_playlists.dart';

part 'profile_stats.g.dart';

/// Library counts shown on the Profile screen's stats row (Phase Z
/// redesign). Server-derived from providers the app already fetches
/// elsewhere — no new endpoints, and all three sources are L5 cache-aware
/// so the row still renders offline.
class ProfileStats {
  const ProfileStats({
    required this.playlists,
    required this.songs,
    required this.albums,
    required this.artists,
  });

  final int playlists;
  final int songs;
  final int albums;
  final int artists;
}

/// Sums the three library list providers into [ProfileStats]. `songs` sums
/// each [Album.songCount] (null-safe — Subsonic always populates it on
/// `getAlbumList2`, but a stray null contributes zero rather than throwing).
///
/// Undercounts past 500 albums: [libraryAlbumsProvider] pages at 500 (same
/// cap as the Albums sub-tab) — acceptable for a stats display.
@riverpod
Future<ProfileStats> profileStats(ProfileStatsRef ref) async {
  final List<Playlist> playlists =
      await ref.watch(libraryPlaylistsProvider.future);
  final List<Album> albums = await ref.watch(libraryAlbumsProvider.future);
  final List<ArtistIndex> artistIndex =
      await ref.watch(libraryArtistsProvider.future);

  final int songs =
      albums.fold<int>(0, (int sum, Album a) => sum + (a.songCount ?? 0));
  final int artists = artistIndex.fold<int>(
      0, (int sum, ArtistIndex idx) => sum + idx.artist.length);

  return ProfileStats(
    playlists: playlists.length,
    songs: songs,
    albums: albums.length,
    artists: artists,
  );
}

/// Compact count formatting for the stats row: `999` stays `999`, `1234`
/// becomes `1.2K`, `1_500_000` becomes `1.5M`. One decimal place, trailing
/// `.0` dropped.
String formatStatCount(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) return '${_trimZero(n / 1000)}K';
  return '${_trimZero(n / 1000000)}M';
}

String _trimZero(double v) {
  final String s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}
