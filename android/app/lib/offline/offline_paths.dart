import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/server_creds.dart';

part 'offline_paths.g.dart';

/// Per-server filesystem layout helpers for the offline-download feature.
///
/// Layout (see `android/docs/ROADMAP_OFFLINE.md` §Architecture):
///
/// ```
/// <appDocs>/offline/<server-key>/
/// ├── manifest.json
/// ├── songs/<songId>.<suffix>
/// └── covers/<albumId>.jpg
/// ```
///
/// `<server-key>` = `sha256(navidromeBaseUrl + "|" + navidromeUsername)`
/// truncated to the first 16 hex characters. The truncation keeps paths
/// short; 16 hex chars = 64 bits of entropy, comfortably collision-free for
/// the single-user, handful-of-servers reality.
///
/// Path resolution is intentionally fail-soft: if the active settings have
/// no Navidrome creds, the helpers return `null` instead of throwing. The
/// caller (`OfflineSync` at L2) treats `null` as a no-op for the tick.
class OfflinePaths {
  OfflinePaths(this._documentsRoot);

  final Directory _documentsRoot;

  Directory get offlineRoot => Directory('${_documentsRoot.path}/offline');

  static String serverKey({
    required String navidromeBaseUrl,
    required String navidromeUsername,
  }) {
    final String raw = '$navidromeBaseUrl|$navidromeUsername';
    final Digest digest = sha256.convert(utf8.encode(raw));
    return digest.toString().substring(0, 16);
  }

  /// Returns `null` when Navidrome creds are missing. Caller skips the tick.
  Directory? serverRoot(ServerCreds settings) {
    final String? url = settings.navidromeBaseUrl;
    final String? user = settings.navidromeUsername;
    if (url == null || user == null || url.isEmpty || user.isEmpty) {
      return null;
    }
    final String key = serverKey(navidromeBaseUrl: url, navidromeUsername: user);
    return Directory('${offlineRoot.path}/$key');
  }

  File? manifestFile(ServerCreds settings) {
    final Directory? root = serverRoot(settings);
    if (root == null) return null;
    return File('${root.path}/manifest.json');
  }

  Directory? songsDir(ServerCreds settings) {
    final Directory? root = serverRoot(settings);
    if (root == null) return null;
    return Directory('${root.path}/songs');
  }

  File? songFile(ServerCreds settings, String songId, String suffix) {
    final Directory? dir = songsDir(settings);
    if (dir == null) return null;
    // Suffix is server-supplied; strip a leading dot if Navidrome gave one.
    final String ext = suffix.startsWith('.') ? suffix.substring(1) : suffix;
    return File('${dir.path}/$songId.$ext');
  }

  /// L5: directory holding JSON snapshots of Subsonic library responses.
  /// One file per logical key (`albums.json`, `album_<id>.json`, etc).
  Directory? libraryCacheDir(ServerCreds settings) {
    final Directory? root = serverRoot(settings);
    if (root == null) return null;
    return Directory('${root.path}/library_cache');
  }

  File? libraryCacheFile(ServerCreds settings, String key) {
    final Directory? dir = libraryCacheDir(settings);
    if (dir == null) return null;
    return File('${dir.path}/$key.json');
  }

  /// L5: directory holding cached cover-art JPGs. Filename is the
  /// Subsonic `coverArtId` (NOT the album id — Navidrome surfaces the
  /// cover id separately so the same cover can be shared by multiple
  /// albums).
  Directory? coversDir(ServerCreds settings) {
    final Directory? root = serverRoot(settings);
    if (root == null) return null;
    // `_hi` is a one-time cache-bust: covers were originally fetched at
    // the widget's render size (~56px) and cached under `covers/`. We
    // now request a fixed 512px so old files would freeze the lo-res
    // bitmap into every later render. Pointing at a fresh directory
    // ignores the stale set; the orphaned `covers/` dir is harmless and
    // gets wiped by "Clear all downloads" alongside everything else.
    return Directory('${root.path}/covers_hi');
  }

  File? coverFile(ServerCreds settings, String coverArtId) {
    final Directory? dir = coversDir(settings);
    if (dir == null) return null;
    // coverArtId can contain forbidden filesystem chars on edge cases. Most
    // Subsonic IDs are short alphanumerics so a basic sanitization suffices.
    final String safe = coverArtId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return File('${dir.path}/$safe.jpg');
  }
}

/// Resolves the app-private documents directory once and caches it.
///
/// Test override: `applicationDocumentsDirectoryProvider.overrideWith(
///   (ref) async => Directory(tmp.path),
/// )`.
@Riverpod(keepAlive: true)
Future<Directory> applicationDocumentsDirectory(
  ApplicationDocumentsDirectoryRef ref,
) async {
  return getApplicationDocumentsDirectory();
}

@Riverpod(keepAlive: true)
Future<OfflinePaths> offlinePaths(OfflinePathsRef ref) async {
  final Directory docs = await ref.watch(
    applicationDocumentsDirectoryProvider.future,
  );
  return OfflinePaths(docs);
}
