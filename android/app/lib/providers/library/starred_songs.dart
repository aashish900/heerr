import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/subsonic/song.dart';
import '../../services/subsonic_library_service.dart';

part 'starred_songs.g.dart';

/// The user's starred ("loved") songs via `getStarred2.view`. Powers the
/// Favorites screen reached from Home's Quick Access row (HOMESCREEN.md
/// task 5).
@riverpod
Future<List<Song>> starredSongs(StarredSongsRef ref) async {
  final SubsonicLibraryService service =
      await ref.watch(subsonicLibraryServiceProvider.future);
  return service.getStarredSongs();
}
