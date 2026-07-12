import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../offline/offline_manifest.dart';
import '../offline/offline_settings.dart';
import '../offline/offline_sync.dart';

part 'sync_activity.g.dart';

/// Downloads "Sync Center" activity row (DL4, DOWNLOADSSCREEN.md §3): counts
/// derived from the manifest's per-song states plus the global Wi-Fi-only
/// gate. Per-song titles/byte-progress aren't tracked (D5, DEBT.md) so this
/// stays count-based — "3 downloading" rather than a named song.
typedef SyncActivity = ({
  int downloadingCount,
  int queuedCount,
  int failedCount,
  bool waitingForWifi,
});

@riverpod
Future<SyncActivity> syncActivity(SyncActivityRef ref) async {
  final OfflineManifest manifest = await ref.watch(offlineManifestProvider.future);

  int downloading = 0;
  int queued = 0;
  int failed = 0;
  for (final OfflineSongEntry e in manifest.songs.values) {
    switch (e.state) {
      case OfflineSongState.downloading:
        downloading++;
      case OfflineSongState.queued:
        queued++;
      case OfflineSongState.failed:
        failed++;
      case OfflineSongState.ready:
        break;
    }
  }

  final OfflineSettingsValue settings = await ref.watch(offlineSettingsProvider.future);
  bool waitingForWifi = false;
  if (settings.wifiOnly && (downloading > 0 || queued > 0)) {
    final bool onWifi = await ref.read(wifiCheckProvider).isOnWifi();
    waitingForWifi = !onWifi;
  }

  return (
    downloadingCount: downloading,
    queuedCount: queued,
    failedCount: failed,
    waitingForWifi: waitingForWifi,
  );
}
