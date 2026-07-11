import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/subsonic/album.dart';
import '../../services/subsonic_library_service.dart';

part 'home_providers.g.dart';

/// Number of albums fetched for the Home "Recently Added" section.
const int _kHomeAlbumSectionSize = 8;

/// Recently-added albums (`getAlbumList2.view?type=newest` — Subsonic
/// "newest" = most recently *added*, distinct from `recent` = recently
/// *played*). Home's only network-bound section post-redesign
/// (HOMESCREEN.md task 6); it doubles as the screen's canonical
/// network-health signal for the auto-retry loop.
@riverpod
Future<List<Album>> homeNewest(HomeNewestRef ref) async {
  final SubsonicLibraryService service =
      await ref.watch(subsonicLibraryServiceProvider.future);
  return service.getAlbumList(type: 'newest', size: _kHomeAlbumSectionSize);
}

/// Full recently-added list for the "See all" screen. Separate provider
/// (not a rerun of [homeNewest]) so the Home section's 8-row fetch and the
/// screen's 50-row fetch cache independently.
@riverpod
Future<List<Album>> recentlyAddedFull(RecentlyAddedFullRef ref) async {
  final SubsonicLibraryService service =
      await ref.watch(subsonicLibraryServiceProvider.future);
  return service.getAlbumList(type: 'newest', size: 50);
}
