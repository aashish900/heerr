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
/// `playback_actions._toMediaItem` reads this and forwards the result to
/// `songToMediaItem(localFilePath: ...)`. Every play surface funnels through
/// that helper, so this provider is the only place that decides local vs.
/// stream.
@riverpod
String? localUriFor(LocalUriForRef ref, String songId) {
  final OfflineSettingsValue? settings =
      ref.watch(offlineSettingsProvider).valueOrNull;
  if (settings == null || !settings.enabled) return null;

  final OfflineManifest? manifest =
      ref.watch(offlineManifestProvider).valueOrNull;
  if (manifest == null) return null;

  final OfflineSongEntry? entry = manifest.songs[songId];
  if (entry == null) return null;
  if (entry.state != OfflineSongState.ready) return null;

  final String? path = entry.localPath;
  if (path == null || path.isEmpty) return null;

  return Uri.file(path).toString();
}
