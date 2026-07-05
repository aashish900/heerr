import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/subsonic/lyrics.dart';
import '../providers/server_creds.dart';
import 'offline_paths.dart';

/// #26: per-server on-disk lyrics cache — `<serverKey>/lyrics/<songId>.json`,
/// one [Lyrics] JSON per file (including timed `lines` when the source was
/// synced). Same fail-soft posture as the L5 library cache: every helper
/// swallows I/O errors and returns null / no-ops, because lyrics are a
/// nice-to-have that must never break playback or sync.
class LyricsCache {
  const LyricsCache(this._paths);

  final OfflinePaths _paths;

  Future<void> write(ServerCreds settings, String songId, Lyrics lyrics) async {
    final File? file = _paths.lyricsFile(settings, songId);
    if (file == null) return;
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(lyrics.toJson()));
    } catch (e) {
      debugPrint('lyrics_cache: write failed for $songId: $e');
    }
  }

  Future<Lyrics?> read(ServerCreds settings, String songId) async {
    final File? file = _paths.lyricsFile(settings, songId);
    if (file == null) return null;
    try {
      if (!await file.exists()) return null;
      final dynamic decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      return Lyrics.fromJson(decoded);
    } catch (e) {
      debugPrint('lyrics_cache: read failed for $songId: $e');
      return null;
    }
  }
}
