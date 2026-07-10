// Named `client` param kept public (not `_client`) so the call site reads
// cleanly; same trade-off as now_playing_persistence.dart.
// ignore_for_file: prefer_initializing_formals

import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';

import '../player/heerr_audio_handler.dart';
import '../utils/palette.dart';

/// #20: home-screen "Now Playing" widget.
///
/// The 4x2 "hero" tile: album art, track title + artist, a gradient
/// waveform + progress bar with m:ss times, and a play/pause / next /
/// previous control row (with an idle "Start listening" state when nothing
/// is queued). Controls are wired natively in [HeroWidgetProvider.kt] as
/// `ACTION_MEDIA_BUTTON` broadcasts to
/// `com.ryanheise.audioservice.MediaButtonReceiver`, so they drive the
/// **live** audio_service MediaSession — no background isolate, no second
/// player instance.
///
/// Cover art is rendered as a **small left thumbnail** only (the native side
/// decodes it heavily downsampled). The earlier full-bleed-background bitmap
/// approach caused repeated blank-widget / race bugs (see DEBT.md #20); the
/// caching here is race-safe (per-URL file, unique temp + atomic rename,
/// in-flight coalescing, staleness guard). This Dart side pushes display
/// state + the cached art path; the native provider name + these data keys
/// are the contract the RemoteViews reads.

/// Must match the Kotlin `HeroWidgetProvider` class (and its manifest
/// `<receiver android:name>` entry). The only home-screen widget as of the
/// gradient redesign — the earlier "classic"/"bar"/"pill" widgets were
/// retired in favour of this single 4x2 tile.
const String kHeroWidgetName = 'HeroWidgetProvider';

const String kNpKeyHasTrack = 'np_has_track';
const String kNpKeyTitle = 'np_title';
const String kNpKeyArtist = 'np_artist';
const String kNpKeyPlaying = 'np_playing';

/// Playback position / track duration in milliseconds, stored as decimal
/// strings (empty when unknown). Consumed by the hero widget's display-only
/// progress bar. Strings (not ints) so the native side parses with
/// `toLongOrNull`, matching the tint-key convention.
const String kNpKeyPositionMs = 'np_position_ms';
const String kNpKeyDurationMs = 'np_duration_ms';

/// Cover-derived background tint as a **signed 32-bit ARGB int**, stored as a
/// decimal string (empty when none). Signed so it fits Kotlin's `Int` —
/// `0xFF......` as an unsigned value overflows `Int.toIntOrNull`. The native
/// side paints the tile background this colour; no bitmaps involved.
const String kNpKeyTintArgb = 'np_tint_argb';

/// Absolute path to the cached cover-art file (empty when none). The widget
/// runs in the same app uid, so it reads this app-private file directly.
const String kNpKeyArtPath = 'np_art_path';

/// Downloads cover art to a stable on-disk file the native widget can decode.
/// Seam so [NowPlayingWidgetUpdater] is testable without network / filesystem.
abstract class WidgetArtCache {
  /// Fetch [artUri] and write it to a per-URL cache file. Returns the absolute
  /// path, or null on failure.
  Future<String?> cache(Uri artUri);
}

class WidgetArtCacheImpl implements WidgetArtCache {
  WidgetArtCacheImpl({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  Future<String?> cache(Uri artUri) async {
    try {
      final Response<List<int>> resp = await _dio.getUri<List<int>>(
        artUri,
        options: Options(responseType: ResponseType.bytes),
      );
      final List<int>? bytes = resp.data;
      if (bytes == null || bytes.isEmpty) return null;
      final Directory dir = await getApplicationSupportDirectory();
      // Per-URL filename so a superseded download can't clobber the file the
      // current track points at; unique temp + atomic rename so the native
      // side never decodes a half-written file.
      final String base = 'np_art_${artUri.toString().hashCode & 0x7fffffff}';
      final File file = File('${dir.path}/$base.png');
      final File tmp =
          File('${dir.path}/$base.${DateTime.now().microsecondsSinceEpoch}.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(file.path);
      return file.path;
    } catch (e, st) {
      debugPrint('now_playing_widget: art fetch failed: $e');
      debugPrintStack(stackTrace: st);
      return null;
    }
  }
}

/// Seam over the cover-art → tint-colour computation so [NowPlayingWidgetUpdater]
/// is testable without the network / `palette_generator`.
abstract class WidgetTintExtractor {
  /// A darkened, white-text-legible ARGB int for [artUri]'s cover, or null
  /// when there is no cover / extraction fails. Only http(s) URIs resolve.
  Future<int?> argbFor(Uri artUri);
}

class WidgetTintExtractorImpl implements WidgetTintExtractor {
  const WidgetTintExtractorImpl();

  @override
  Future<int?> argbFor(Uri artUri) async {
    final Color? c = await dominantColorFor(artUri);
    if (c == null) return null;
    // Darken toward black (~50%) so white title/artist stay legible on the
    // tile regardless of how bright the cover swatch is.
    int chan(double v) => (v * 255 * 0.5).round().clamp(0, 255);
    final int argb =
        (0xFF << 24) | (chan(c.r) << 16) | (chan(c.g) << 8) | chan(c.b);
    return argb.toSigned(32);
  }
}

/// Thin seam over the static [HomeWidget] API so [NowPlayingWidgetUpdater]
/// is unit-testable without the platform channel. Production wiring uses
/// [HomeWidgetClientImpl]; tests inject a mock.
abstract class HomeWidgetClient {
  Future<void> saveString(String key, String? value);
  Future<void> saveBool(String key, bool value);
  Future<void> update();
}

class HomeWidgetClientImpl implements HomeWidgetClient {
  const HomeWidgetClientImpl();

  @override
  Future<void> saveString(String key, String? value) =>
      HomeWidget.saveWidgetData<String?>(key, value);

  @override
  Future<void> saveBool(String key, bool value) =>
      HomeWidget.saveWidgetData<bool>(key, value);

  @override
  Future<void> update() async {
    // Redraw the hero widget; a harmless no-op if the user hasn't added it.
    await HomeWidget.updateWidget(
      name: kHeroWidgetName,
      androidName: kHeroWidgetName,
    );
  }
}

/// Maps a [PlayerSnapshot] onto the widget's data keys and asks the OS to
/// redraw. All failures are swallowed — a missing-platform / no-widget-added
/// error must never break playback.
class NowPlayingWidgetUpdater {
  NowPlayingWidgetUpdater({
    required HomeWidgetClient client,
    WidgetTintExtractor? tintExtractor,
    WidgetArtCache? artCache,
  })  : _client = client,
        _tint = tintExtractor,
        _art = artCache;

  final HomeWidgetClient _client;
  final WidgetTintExtractor? _tint;
  final WidgetArtCache? _art;

  // Per-track guard: the cover (and thus tint) only changes on track change,
  // so we don't recompute the palette on every play/pause/position emission.
  String? _lastTintUri;
  String _lastTint = '';

  // Same per-track guard + in-flight coalescing for the cover thumbnail.
  String? _lastArtUri;
  String _lastArtPath = '';
  String? _inFlightArtUri;
  Future<String?>? _inFlightArt;

  Future<void> push(PlayerSnapshot snapshot) async {
    final MediaItem? item = snapshot.item;
    if (item == null) {
      await clear();
      return;
    }
    try {
      await _client.saveBool(kNpKeyHasTrack, true);
      await _client.saveString(kNpKeyTitle, item.title);
      await _client.saveString(kNpKeyArtist, item.artist ?? '');
      await _client.saveBool(kNpKeyPlaying, snapshot.isPlaying);
      await _client.saveString(kNpKeyTintArgb, await _resolveTint(item));
      await _client.saveString(kNpKeyArtPath, await _resolveArtPath(item));
      // Hero-widget progress. Snapshots only emit on transport changes, so
      // this snaps to the new position on play/pause/seek/track-change; the
      // live ticker ([pushPosition]) covers the in-between seconds.
      await _client.saveString(
        kNpKeyPositionMs,
        snapshot.position.inMilliseconds.toString(),
      );
      await _client.saveString(
        kNpKeyDurationMs,
        (item.duration?.inMilliseconds ?? 0).toString(),
      );
      await _client.update();
    } catch (e, st) {
      debugPrint('now_playing_widget: push failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  /// Lightweight position-only push for the live 1 s progress ticker. Writes
  /// just [kNpKeyPositionMs] and redraws — no tint/art re-resolution — so the
  /// hero widget's progress advances each second without the per-track work
  /// [push] does. Callers should only tick while a track is playing.
  Future<void> pushPosition(Duration position) async {
    try {
      await _client.saveString(
        kNpKeyPositionMs,
        position.inMilliseconds.toString(),
      );
      await _client.update();
    } catch (e, st) {
      debugPrint('now_playing_widget: pushPosition failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  /// Cover-derived tint as a signed-ARGB string, computed once per track.
  /// Empty when there is no extractor or no network cover.
  Future<String> _resolveTint(MediaItem item) async {
    final WidgetTintExtractor? ext = _tint;
    final Uri? art = item.artUri;
    final bool isNetwork =
        art != null && (art.isScheme('http') || art.isScheme('https'));
    if (ext == null || !isNetwork) {
      _lastTintUri = null;
      _lastTint = '';
      return '';
    }
    final String url = art.toString();
    if (url == _lastTintUri) return _lastTint;
    _lastTintUri = url;
    final int? argb = await ext.argbFor(art);
    if (_lastTintUri != url) return _lastTint; // superseded by a newer track
    _lastTint = argb?.toString() ?? '';
    return _lastTint;
  }

  /// On-disk cover path, fetched once per track. Empty when there is no cache
  /// or no network cover. Coalesces concurrent fetches and ignores a stale
  /// download whose track was already skipped past.
  Future<String> _resolveArtPath(MediaItem item) async {
    final WidgetArtCache? cache = _art;
    final Uri? art = item.artUri;
    final bool isNetwork =
        art != null && (art.isScheme('http') || art.isScheme('https'));
    if (cache == null || !isNetwork) {
      _lastArtUri = null;
      _lastArtPath = '';
      return '';
    }
    final String url = art.toString();
    if (url == _lastArtUri) return _lastArtPath;

    final Future<String?> fetch;
    if (_inFlightArtUri == url && _inFlightArt != null) {
      fetch = _inFlightArt!;
    } else {
      fetch = cache.cache(art);
      _inFlightArt = fetch;
      _inFlightArtUri = url;
    }
    final String? path = await fetch;
    if (identical(_inFlightArt, fetch)) {
      _inFlightArt = null;
      _inFlightArtUri = null;
    }
    if (_inFlightArtUri != null && _inFlightArtUri != url) {
      // A newer track is already being fetched; don't clobber its art.
      return _lastArtPath;
    }
    _lastArtUri = url;
    _lastArtPath = path ?? '';
    return _lastArtPath;
  }

  /// Reset the widget to its empty "nothing playing" state.
  Future<void> clear() async {
    _lastTintUri = null;
    _lastTint = '';
    _lastArtUri = null;
    _lastArtPath = '';
    try {
      await _client.saveBool(kNpKeyHasTrack, false);
      await _client.saveString(kNpKeyTitle, '');
      await _client.saveString(kNpKeyArtist, '');
      await _client.saveBool(kNpKeyPlaying, false);
      await _client.saveString(kNpKeyTintArgb, '');
      await _client.saveString(kNpKeyArtPath, '');
      await _client.saveString(kNpKeyPositionMs, '');
      await _client.saveString(kNpKeyDurationMs, '');
      await _client.update();
    } catch (e, st) {
      debugPrint('now_playing_widget: clear failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }
}
