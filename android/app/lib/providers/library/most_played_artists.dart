import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/subsonic/album.dart';
import '../../services/subsonic_library_service.dart';

part 'most_played_artists.g.dart';

/// Rail cap — the artists list itself is the "see all" surface.
const int kMostPlayedArtistsCap = 10;

/// One entry of the Artists tab's "Most Played Artists" rail (X5).
///
/// Subsonic has no frequent-*artists* endpoint, so entries are derived from
/// `getAlbumList2?type=frequent` albums: the first album naming an artist
/// wins (list is already play-count ordered), its cover doubles as the
/// avatar, and its id is the play-badge target.
class MostPlayedArtist {
  const MostPlayedArtist({
    required this.artistId,
    required this.name,
    required this.topAlbumId,
    this.coverArt,
  });

  final String artistId;
  final String name;

  /// The artist's most-played album — the rail's play badge plays it.
  final String topAlbumId;

  /// Cover of [topAlbumId]; the rail renders it as a circular avatar.
  final String? coverArt;
}

/// Visible for tests: dedupes a frequent-albums list into rail entries,
/// preserving play-count order, skipping albums without an artist id.
List<MostPlayedArtist> mostPlayedArtistsFrom(List<Album> frequentAlbums) {
  final Map<String, MostPlayedArtist> byArtist =
      <String, MostPlayedArtist>{};
  for (final Album album in frequentAlbums) {
    final String? artistId = album.artistId;
    final String? name = album.artist;
    if (artistId == null || name == null) continue;
    byArtist.putIfAbsent(
      artistId,
      () => MostPlayedArtist(
        artistId: artistId,
        name: name,
        topAlbumId: album.id,
        coverArt: album.coverArt,
      ),
    );
    if (byArtist.length >= kMostPlayedArtistsCap) break;
  }
  return byArtist.values.toList();
}

@riverpod
Future<List<MostPlayedArtist>> mostPlayedArtists(
    MostPlayedArtistsRef ref) async {
  final SubsonicLibraryService service =
      await ref.watch(subsonicLibraryServiceProvider.future);
  final List<Album> frequent =
      await service.getAlbumList(type: 'frequent', size: 50);
  return mostPlayedArtistsFrom(frequent);
}
