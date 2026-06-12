import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'offline_manifest.dart';
import 'offline_settings.dart';

part 'local_uri.g.dart';

/// Single chokepoint that the playback layer queries to decide whether to
/// open a local file or stream over the network.
///
/// Returns:
/// - `null` when the offline master switch is OFF (treat as stream-only).
/// - `null` when there's no manifest entry for [songId].
/// - `null` when the entry exists but state is not [OfflineSongState.ready].
/// - A `file://` URI string when the entry is `ready` with a `localPath`.
///
/// **Async on purpose.** Earlier this was a sync provider that read
/// `manifest.valueOrNull`. That gave a real bug: right after a sync
/// `ref.invalidate(offlineManifestProvider)` puts the manifest into a
/// loading state with the *previous* AsyncData snapshot attached. A
/// playback action that called `ref.read(localUriForProvider(songId))`
/// in that window saw the stale pre-sync manifest, didn't find a
/// `ready` entry, and quietly fell back to the stream URL — which then
/// failed offline. The user observed "I have to download twice for it
/// to play." Awaiting `manifest.future` blocks until the rebuild
/// completes (manifest is a disk read, fast even offline), so the
/// playback layer always sees the freshly persisted entry.
///
/// `playback_actions._toMediaItem` awaits this and forwards the result
/// to `songToMediaItem(localFilePath: ...)`. Every play surface funnels
/// through that helper, so this provider is the only place that decides
/// local vs. stream.
@riverpod
Future<String?> localUriFor(LocalUriForRef ref, String songId) async {
  final OfflineSettingsValue settings =
      await ref.watch(offlineSettingsProvider.future);
  if (!settings.enabled) return null;

  final OfflineManifest manifest =
      await ref.watch(offlineManifestProvider.future);

  final OfflineSongEntry? entry = manifest.songs[songId];
  if (entry == null) return null;
  if (entry.state != OfflineSongState.ready) return null;

  final String? path = entry.localPath;
  if (path == null || path.isEmpty) return null;

  return Uri.file(path).toString();
}
