import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/recommended_track.dart';
import '../../models/subsonic/album.dart';
import '../../models/subsonic/song.dart';
import '../../services/subsonic_library_service.dart';
import '../recommendations.dart';

part 'home_providers.g.dart';

/// Number of albums fetched for the recently-played + most-played sections.
/// 8 fits 4 columns on a phone with one tall row in the quick-access grid
/// and gives the horizontal sections enough scroll-runway.
const int _kHomeAlbumSectionSize = 8;

/// Random-song pool size. Keeps the homeRandomSongs fallback meaningful
/// without ballooning the round-trip — recommendations section needs up to
/// 20 (`_kRecommendationsLimit`), and the quick-access grid needs 6 albums
/// worth which Navidrome maps from these random songs.
const int _kHomeRandomSongsSize = 20;

/// Recently-played albums (`getAlbumList2.view?type=recent`). The Home
/// screen's "Jump back in" section and primary quick-access grid use this.
@riverpod
Future<List<Album>> homeRecent(HomeRecentRef ref) async {
  final SubsonicLibraryService service =
      await ref.watch(subsonicLibraryServiceProvider.future);
  return service.getAlbumList(type: 'recent', size: _kHomeAlbumSectionSize);
}

/// Most-played albums (`getAlbumList2.view?type=frequent`). Powers the Home
/// screen's "Most played" horizontal section.
@riverpod
Future<List<Album>> homeMostPlayed(HomeMostPlayedRef ref) async {
  final SubsonicLibraryService service =
      await ref.watch(subsonicLibraryServiceProvider.future);
  return service.getAlbumList(type: 'frequent', size: _kHomeAlbumSectionSize);
}

/// Random songs from the library (`getRandomSongs.view`). Used as the
/// universal fallback when backend recommendations come back empty, and as a
/// fill-in for the quick-access grid when "recently played" is empty.
@riverpod
Future<List<Song>> homeRandomSongs(HomeRandomSongsRef ref) async {
  final SubsonicLibraryService service =
      await ref.watch(subsonicLibraryServiceProvider.future);
  return service.getRandomSongs(_kHomeRandomSongsSize);
}

/// Discriminated result shape for [homeRecommendations]. `isFallback` is
/// `true` when the upstream recommendations engine returned nothing and the
/// list was reconstituted from random library songs. The screen uses the
/// flag to switch the section header from "Picked for you" → "Discover".
typedef HomeRecommendations = ({
  List<RecommendedTrack> tracks,
  bool isFallback,
});

/// Recommendation feed for the Home screen.
///
/// Primary source: [recommendationsProvider] (already library-cross-
/// referenced via the N4 `search3` hydration step). When that returns an
/// empty list the notifier maps [homeRandomSongs] to `RecommendedTrack` shape
/// so the section still has content. Songs are local, so `inLibrary=true` and
/// `subsonicSongId` is populated; `sourceUrl` is empty.
@riverpod
Future<HomeRecommendations> homeRecommendations(
    HomeRecommendationsRef ref) async {
  final List<RecommendedTrack> base =
      await ref.watch(recommendationsProvider.future);
  if (base.isNotEmpty) {
    return (tracks: base, isFallback: false);
  }
  final List<Song> random = await ref.watch(homeRandomSongsProvider.future);
  final List<RecommendedTrack> mapped = random
      .where((Song s) => s.artist != null && s.artist!.isNotEmpty)
      .map((Song s) => RecommendedTrack(
            title: s.title,
            artist: s.artist!,
            sourceUrl: '',
            inLibrary: true,
            subsonicSongId: s.id,
            coverArt: s.coverArt,
          ))
      .toList();
  return (tracks: mapped, isFallback: true);
}
