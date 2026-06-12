import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/subsonic_client.dart';
import '../offline/library_cache.dart';
import '../offline/offline_downloader.dart';
import '../offline/offline_paths.dart';
import '../providers/settings.dart';

/// Renders a Subsonic `coverArt` image.
///
/// L5 cache behaviour: on first build the widget probes the per-server
/// cover cache at `<offlineRoot>/<server-key>/covers/<coverArtId>.jpg`.
/// - **Cache hit** → renders `Image.file` directly. Survives full offline.
/// - **Cache miss + online** → fetches once via the no-interceptor offline
///   Dio (`offlineDownloadDioProvider`), persists the bytes, then renders
///   `Image.file`. Single round trip per cover; the next render of the
///   same coverArt is a pure cache hit.
/// - **Cache miss + offline** (no creds OR download fails) → placeholder.
///
/// The Subsonic cover URL embeds auth in the query string, so the
/// no-interceptor Dio is the correct client (the auth interceptor would
/// double-sign and 401). Errors are swallowed → placeholder; the next
/// online visit re-tries the fetch.
class LibraryCoverArt extends ConsumerStatefulWidget {
  const LibraryCoverArt({
    required this.coverArtId,
    this.size = 56,
    this.borderRadius = 4,
    super.key,
  });

  final String? coverArtId;
  final double size;
  final double borderRadius;

  @override
  ConsumerState<LibraryCoverArt> createState() => _LibraryCoverArtState();
}

class _LibraryCoverArtState extends ConsumerState<LibraryCoverArt> {
  File? _file;

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  @override
  void didUpdateWidget(LibraryCoverArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverArtId != widget.coverArtId) {
      _file = null;
      unawaited(_resolve());
    }
  }

  Future<void> _resolve() async {
    final String? id = widget.coverArtId;
    if (id == null || id.isEmpty) return;
    try {
      final OfflinePaths paths =
          await ref.read(offlinePathsProvider.future);
      final SettingsValue settings =
          await ref.read(settingsProvider.future);
      final File? file = paths.coverFile(settings, id);
      if (file == null) return;
      if (await file.exists()) {
        if (mounted) setState(() => _file = file);
        return;
      }
      // Cache miss — fetch once, persist, then render.
      final String? baseUrl = settings.navidromeBaseUrl;
      final String? user = settings.navidromeUsername;
      final String? pass = settings.navidromePassword;
      if (baseUrl == null || baseUrl.isEmpty ||
          user == null || user.isEmpty ||
          pass == null || pass.isEmpty) {
        return;
      }
      // L5-followup: skip the network entirely when offline. Without
      // this, every visible tile fans out a Dio request that waits the
      // full connectTimeout — N tiles × 10s freezes the Library scroll
      // even though we already know the carrier is gone.
      try {
        final OnlineCheck check = ref.read(onlineCheckProvider);
        if (!await check.isLikelyOnline()) return;
      } catch (_) {
        // Probe broken → fall through and try the fetch (bounded below).
      }
      // Always fetch + cache at a fixed high resolution rather than the
      // widget's current render size. Two reasons:
      // 1. The cache file is keyed by coverArtId only, so a small first
      //    request would freeze a low-quality bitmap on disk that every
      //    later (larger) render of the same id reuses.
      // 2. The tile renders at widget.size dp; on a 3x device that is
      //    3x more physical pixels. Asking Subsonic for 56px and then
      //    upscaling visibly blurs the artwork.
      // 512 is a generous fixed ceiling: sharp at any tile size the app
      // currently uses (LibraryResultTile, the now-playing strip, etc.)
      // while keeping the per-cover disk cost under ~50 KB.
      const int kCoverFetchSize = 512;
      final String url = buildSubsonicCoverArtUrl(
        baseUrl: baseUrl,
        username: user,
        password: pass,
        coverArtId: id,
        size: kCoverFetchSize,
      );
      final Dio dio = ref.read(offlineDownloadDioProvider);
      // Hard cap the cover fetch — placeholder is fine, a frozen tile
      // is not. The next online visit retries.
      final Response<List<int>> resp = await dio
          .get<List<int>>(
            url,
            options: Options(responseType: ResponseType.bytes),
          )
          .timeout(const Duration(seconds: 4));
      final List<int>? data = resp.data;
      if (data == null || data.isEmpty) return;
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data, flush: true);
      if (mounted) setState(() => _file = file);
    } catch (e) {
      // Network failure / disk error → silently degrade to placeholder.
      // Next online visit retries the fetch.
      debugPrint('library_cover_art: resolve ${widget.coverArtId} failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? id = widget.coverArtId;
    if (id == null || id.isEmpty) return _placeholder(context);

    final File? file = _file;
    if (file != null) {
      // The on-disk JPEG is fixed at 512px; tell Flutter to decode at
      // the actual physical pixel count this tile occupies. Without
      // this the framework decodes the full 512px bitmap for every
      // visible tile (50 tiles ≈ 50 MB of RGBA in memory).
      final double dpr = MediaQuery.devicePixelRatioOf(context);
      final int decodePx = (widget.size * dpr).round();
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Image.file(
          file,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          cacheWidth: decodePx,
          cacheHeight: decodePx,
          errorBuilder: (BuildContext c, _, _) => _placeholder(c),
        ),
      );
    }
    // Still resolving (initState fired but disk probe / download not done)
    // OR resolved with no file → render placeholder. The widget rebuilds
    // automatically when _file is set via setState.
    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: Icon(Icons.music_note, color: cs.onSurfaceVariant),
    );
  }
}
