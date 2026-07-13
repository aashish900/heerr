import 'dart:io';

/// `Directory.delete(recursive: true)` snapshots the tree once, then deletes
/// bottom-up; a file dropped into (or removed from) the tree mid-walk by a
/// concurrent writer — cover art / library cache / lyrics caching (any of
/// which can write under the same per-server directory while the user is
/// simply browsing), or a sync tick that started just before the caller
/// paused it — makes the affected subdirectory's delete fail (`ENOTEMPTY`
/// "Directory not empty", or occasionally `ENOENT` if a nested entry vanished
/// between listing and deleting it). Retrying re-snapshots the tree, so a
/// transient extra/missing entry just gets swept up on the next pass — this
/// is exactly what manually retrying the "Clear all downloads" button
/// already did before this helper existed.
Future<void> deleteRecursiveWithRetry(Directory dir, {int attempts = 5}) async {
  for (int attempt = 1; attempt <= attempts; attempt++) {
    if (!await dir.exists()) return;
    try {
      await dir.delete(recursive: true);
      return;
    } on FileSystemException {
      if (attempt == attempts) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }
}
