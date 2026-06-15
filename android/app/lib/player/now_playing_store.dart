import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../offline/offline_paths.dart';
import 'now_playing_snapshot.dart';

part 'now_playing_store.g.dart';

/// Disk-backed load/save for the Now Playing snapshot. Atomic write via
/// tmp-file + rename (same safety pattern as `OfflineManifestStore` at L1).
///
/// Missing or corrupt files fall back to `null` — the next save overwrites
/// the corruption. Restore code treats null as "nothing to restore" and
/// boots a fresh empty queue.
class NowPlayingStore {
  NowPlayingStore(this._file);

  final File _file;

  /// Public for tests + diagnostics.
  File get file => _file;

  Future<NowPlayingSnapshot?> load() async {
    if (!await _file.exists()) return null;
    try {
      final String raw = await _file.readAsString();
      if (raw.trim().isEmpty) return null;
      final Map<String, dynamic> json =
          jsonDecode(raw) as Map<String, dynamic>;
      return NowPlayingSnapshot.fromJson(json);
    } catch (e, st) {
      // Don't crash the app on a corrupt snapshot — debug-log and skip.
      // Next save() rewrites the file.
      debugPrint('now_playing_store: corrupt JSON, ignoring: $e');
      debugPrintStack(stackTrace: st);
      return null;
    }
  }

  Future<void> save(NowPlayingSnapshot snapshot) async {
    await _file.parent.create(recursive: true);
    final File tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(jsonEncode(snapshot.toJson()), flush: true);
    await tmp.rename(_file.path);
  }

  /// Delete the snapshot file. Used by tests + (future) "Reset queue"
  /// settings affordances. No-op if missing.
  Future<void> clear() async {
    if (await _file.exists()) {
      await _file.delete();
    }
  }
}

/// File at `<appDocs>/now_playing.json`. Reuses the same
/// [applicationDocumentsDirectoryProvider] the offline layer uses (L1).
@Riverpod(keepAlive: true)
Future<NowPlayingStore> nowPlayingStore(NowPlayingStoreRef ref) async {
  final Directory docs = await ref.watch(
    applicationDocumentsDirectoryProvider.future,
  );
  return NowPlayingStore(File('${docs.path}/now_playing.json'));
}
