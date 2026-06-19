import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api/api_error.dart';
import '../api/subsonic_client.dart';
import '../models/subsonic/song.dart';
import '../providers/server_creds.dart';
import 'offline_manifest.dart';
import 'offline_paths.dart';

part 'offline_downloader.g.dart';

/// Stream-and-store one Subsonic [song] to the per-server `songs/` directory.
///
/// Side-effect contract:
/// - Writes to `<...>/songs/<id>.<suffix>.partial` first, renames on success.
/// - Verifies `file.length() == song.size` when the server advertises a size
///   — a mismatch deletes the file and returns a `failed` entry.
/// - Any `DioException` is mapped via [mapDioErrorToApiError]; the resulting
///   [ApiError.message] lands in `OfflineSongEntry.lastError`.
/// - Any `FileSystemException` (full disk, permission) is caught the same way.
///
/// Auth: the stream URL already carries Subsonic auth params (`u/s/t/v/c`).
/// The injected [downloadDio] **must have no interceptors** — a Subsonic
/// interceptor would double-sign and break the request.
///
/// Pure-ish: the function does I/O but takes no Ref. Tests inject a fake
/// `Dio` adapter + a temp [OfflinePaths] root.
Future<OfflineSongEntry> downloadSong({
  required Song song,
  required ServerCreds settings,
  required OfflinePaths paths,
  required Dio downloadDio,
}) async {
  final String? baseUrl = settings.navidromeBaseUrl;
  final String? user = settings.navidromeUsername;
  final String? pass = settings.navidromePassword;
  if (baseUrl == null || user == null || pass == null) {
    return const OfflineSongEntry(
      state: OfflineSongState.failed,
      lastError: 'Navidrome creds missing',
    );
  }

  final String suffix = (song.suffix ?? 'mp3').toLowerCase();
  final File? target = paths.songFile(settings, song.id, suffix);
  if (target == null) {
    return const OfflineSongEntry(
      state: OfflineSongState.failed,
      lastError: 'Navidrome creds missing',
    );
  }

  final String partialPath = '${target.path}.partial';
  final File partial = File(partialPath);

  try {
    await target.parent.create(recursive: true);
    // Clean up any leftover partial from a prior interrupted tick.
    if (await partial.exists()) {
      await partial.delete();
    }

    final String url = buildSubsonicStreamUrl(
      baseUrl: baseUrl,
      username: user,
      password: pass,
      songId: song.id,
    );

    await downloadDio.download(url, partialPath);

    final int actualSize = await partial.length();
    final int? expectedSize = song.size;
    if (expectedSize != null && actualSize != expectedSize) {
      await _safeDelete(partial);
      return OfflineSongEntry(
        state: OfflineSongState.failed,
        lastError:
            'size mismatch: expected $expectedSize bytes, got $actualSize',
      );
    }

    await partial.rename(target.path);

    return OfflineSongEntry(
      state: OfflineSongState.ready,
      localPath: target.path,
      size: actualSize,
      suffix: suffix,
      downloadedAt: DateTime.now(),
    );
  } on DioException catch (e) {
    await _safeDelete(partial);
    final ApiError mapped = mapDioErrorToApiError(e);
    return OfflineSongEntry(
      state: OfflineSongState.failed,
      lastError: mapped.message,
    );
  } on FileSystemException catch (e) {
    await _safeDelete(partial);
    return OfflineSongEntry(
      state: OfflineSongState.failed,
      lastError: 'filesystem error: ${e.message}',
    );
  } catch (e, st) {
    debugPrint('offline_downloader: unexpected error for ${song.id}: $e');
    debugPrintStack(stackTrace: st);
    await _safeDelete(partial);
    return OfflineSongEntry(
      state: OfflineSongState.failed,
      lastError: 'unexpected error: $e',
    );
  }
}

Future<void> _safeDelete(File f) async {
  try {
    if (await f.exists()) await f.delete();
  } catch (_) {
    // Don't compound a failure with a cleanup failure.
  }
}

/// A no-interceptor `Dio` for downloading audio bytes. Kept separate from
/// [subsonicDioClientProvider] because the Subsonic auth interceptor on that
/// instance would double-sign URLs that already carry their own
/// `u/s/t/v/c` params (see `buildSubsonicStreamUrl`).
///
/// Built without a `baseUrl` because [downloadSong] passes absolute URLs.
@Riverpod(keepAlive: true)
Dio offlineDownloadDio(OfflineDownloadDioRef ref) {
  return Dio(
    BaseOptions(
      // Audio downloads are larger than a typical API call; give them
      // generous timeouts. Per-byte progress is handled by dio.download.
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
    ),
  );
}
