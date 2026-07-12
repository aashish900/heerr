import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../offline/offline_manifest.dart';
import '../offline/offline_paths.dart';
import 'server_creds.dart';

part 'storage_breakdown.g.dart';

/// Downloads "Sync Center" storage card (DL7, DOWNLOADSSCREEN.md §5) — actual
/// on-disk usage, unlike `offlineSizeEstimateProvider` (which estimates what
/// a *future* sync-all would take).
typedef StorageBreakdown = ({int music, int artwork, int lyrics, int cache});

@riverpod
Future<StorageBreakdown> storageBreakdown(StorageBreakdownRef ref) async {
  final ServerCreds creds = ref.watch(serverCredsProvider);
  final OfflineManifest manifest = await ref.watch(offlineManifestProvider.future);

  // Music: manifest already tracks each ready song's on-disk size, so this
  // is a cheap sum — no directory walk needed.
  final int music = manifest.songs.values
      .where((OfflineSongEntry e) => e.state == OfflineSongState.ready)
      .fold(0, (int sum, OfflineSongEntry e) => sum + (e.size ?? 0));

  final OfflinePaths paths = await ref.watch(offlinePathsProvider.future);
  final int artwork = await dirSizeBytes(paths.coversDir(creds));
  final int lyrics = await dirSizeBytes(paths.lyricsDir(creds));
  final int cache = await dirSizeBytes(paths.libraryCacheDir(creds));

  return (music: music, artwork: artwork, lyrics: lyrics, cache: cache);
}

/// Recursive file-size sum for [dir]. `null`/missing directory → 0, same
/// fail-soft convention as the rest of `OfflinePaths`. Unreadable individual
/// files are skipped rather than failing the whole walk.
Future<int> dirSizeBytes(Directory? dir) async {
  if (dir == null || !await dir.exists()) return 0;
  int total = 0;
  await for (final FileSystemEntity entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is File) {
      try {
        total += await entity.length();
      } catch (_) {
        // Skip files that vanish/become unreadable mid-walk.
      }
    }
  }
  return total;
}
