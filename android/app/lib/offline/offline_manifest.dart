import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/settings.dart';
import 'offline_paths.dart';

part 'offline_manifest.freezed.dart';
part 'offline_manifest.g.dart';

/// Source-of-truth for "what is marked" + "what is downloaded" for a single
/// server profile. Persisted as JSON at
/// `<appDocs>/offline/<server-key>/manifest.json`.
///
/// `estimatedTotalBytes` + `estimatedAt` cache the L4 sync-all preflight
/// result so re-rendering the Settings screen doesn't refire the library
/// walk. The cache is cleared whenever a marker changes or `syncAll` flips.
@freezed
class OfflineManifest with _$OfflineManifest {
  const factory OfflineManifest({
    @Default(<String>{}) Set<String> markedAlbums,
    @Default(<String>{}) Set<String> markedPlaylists,
    @Default(<String, OfflineSongEntry>{})
    Map<String, OfflineSongEntry> songs,
    int? estimatedTotalBytes,
    DateTime? estimatedAt,
  }) = _OfflineManifest;

  factory OfflineManifest.fromJson(Map<String, dynamic> json) =>
      _$OfflineManifestFromJson(json);
}

/// Lifecycle of a single song's local copy.
enum OfflineSongState {
  @JsonValue('queued')
  queued,
  @JsonValue('downloading')
  downloading,
  @JsonValue('ready')
  ready,
  @JsonValue('failed')
  failed,
}

@freezed
class OfflineSongEntry with _$OfflineSongEntry {
  const factory OfflineSongEntry({
    required OfflineSongState state,
    String? localPath,
    int? size,
    String? suffix,
    DateTime? downloadedAt,
    String? lastError,
  }) = _OfflineSongEntry;

  factory OfflineSongEntry.fromJson(Map<String, dynamic> json) =>
      _$OfflineSongEntryFromJson(json);
}

/// Disk-backed read/write for the manifest. Atomic writes via tmp-file +
/// rename. Missing or corrupt files fall back to an empty manifest — the
/// next save overwrites the corruption.
class OfflineManifestStore {
  OfflineManifestStore(this._paths);

  final OfflinePaths _paths;

  Future<OfflineManifest> load(SettingsValue settings) async {
    final File? file = _paths.manifestFile(settings);
    if (file == null) return const OfflineManifest();
    if (!await file.exists()) return const OfflineManifest();
    try {
      final String raw = await file.readAsString();
      if (raw.trim().isEmpty) return const OfflineManifest();
      final Map<String, dynamic> json =
          jsonDecode(raw) as Map<String, dynamic>;
      return OfflineManifest.fromJson(json);
    } catch (e, st) {
      // Don't crash the app on a corrupt manifest — emit a debug log and
      // start from empty. The next save() rewrites the file.
      debugPrint('offline_manifest: corrupt JSON, falling back to empty: $e');
      debugPrintStack(stackTrace: st);
      return const OfflineManifest();
    }
  }

  Future<void> save(SettingsValue settings, OfflineManifest manifest) async {
    final File? file = _paths.manifestFile(settings);
    if (file == null) {
      throw StateError(
        'offline_manifest: cannot save — Navidrome creds missing',
      );
    }
    await file.parent.create(recursive: true);
    final File tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(manifest.toJson()), flush: true);
    await tmp.rename(file.path);
  }
}

@Riverpod(keepAlive: true)
Future<OfflineManifestStore> offlineManifestStore(
  OfflineManifestStoreRef ref,
) async {
  final OfflinePaths paths = await ref.watch(offlinePathsProvider.future);
  return OfflineManifestStore(paths);
}

/// Current manifest for the active server profile. Watches `settingsProvider`
/// so a profile-switch reloads the manifest under the new server-key.
@Riverpod(keepAlive: true)
Future<OfflineManifest> offlineManifest(OfflineManifestRef ref) async {
  final SettingsValue settings =
      await ref.watch(settingsProvider.future);
  final OfflineManifestStore store =
      await ref.watch(offlineManifestStoreProvider.future);
  return store.load(settings);
}
