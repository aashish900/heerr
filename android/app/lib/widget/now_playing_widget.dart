// Named `client` param kept public (not `_client`) so the call site reads
// cleanly; same trade-off as now_playing_persistence.dart.
// ignore_for_file: prefer_initializing_formals

import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';

import '../player/heerr_audio_handler.dart';

/// #20: home-screen "Now Playing" widget.
///
/// The widget shows the current track's title + artist and a play/pause /
/// next / previous control row. Controls are wired natively in
/// [NowPlayingWidgetProvider.kt] as `ACTION_MEDIA_BUTTON` broadcasts to
/// `com.ryanheise.audioservice.MediaButtonReceiver`, so they drive the
/// **live** audio_service MediaSession — no background isolate, no second
/// player instance.
///
/// This Dart side only pushes display state. The native provider name +
/// these data keys are the contract the RemoteViews reads.

/// Must match the Kotlin `AppWidgetProvider` class (and its manifest
/// `<receiver android:name>`).
const String kNowPlayingWidgetName = 'NowPlayingWidgetProvider';

const String kNpKeyHasTrack = 'np_has_track';
const String kNpKeyTitle = 'np_title';
const String kNpKeyArtist = 'np_artist';
const String kNpKeyPlaying = 'np_playing';

/// Absolute path to the cached cover-art PNG (empty when none). The widget
/// runs in the same app uid, so it can read this app-private file directly.
const String kNpKeyArtPath = 'np_art_path';

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
  Future<void> update() => HomeWidget.updateWidget(
        name: kNowPlayingWidgetName,
        androidName: kNowPlayingWidgetName,
      );
}

/// Downloads cover art to a stable on-disk file the native widget can read.
/// Seam so [NowPlayingWidgetUpdater] is testable without the network /
/// filesystem.
abstract class WidgetArtCache {
  /// Fetch [artUri] and write it to the cache file. Returns the absolute
  /// path, or null on failure. Only http(s) URIs are fetched.
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
      final File file = File('${dir.path}/np_widget_art.png');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e, st) {
      debugPrint('now_playing_widget: art fetch failed: $e');
      debugPrintStack(stackTrace: st);
      return null;
    }
  }
}

/// Maps a [PlayerSnapshot] onto the widget's data keys and asks the OS to
/// redraw. All failures are swallowed — a missing-platform / no-widget-added
/// error must never break playback.
class NowPlayingWidgetUpdater {
  NowPlayingWidgetUpdater({
    required HomeWidgetClient client,
    WidgetArtCache? artCache,
  })  : _client = client,
        _artCache = artCache;

  final HomeWidgetClient _client;
  final WidgetArtCache? _artCache;

  // Per-track guard: cover art only changes when the track changes, so we
  // don't re-download on every play/pause/buffer emission.
  String? _lastArtUri;
  String _lastArtPath = '';

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
      await _client.saveString(kNpKeyArtPath, await _resolveArtPath(item));
      await _client.update();
    } catch (e, st) {
      debugPrint('now_playing_widget: push failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  /// Returns the on-disk path for this item's cover art, fetching it once
  /// per track. Empty string when there is no cache or no network art.
  Future<String> _resolveArtPath(MediaItem item) async {
    final WidgetArtCache? cache = _artCache;
    final Uri? art = item.artUri;
    final bool isNetwork =
        art != null && (art.isScheme('http') || art.isScheme('https'));
    if (cache == null || !isNetwork) {
      _lastArtUri = null;
      _lastArtPath = '';
      return '';
    }
    if (art.toString() == _lastArtUri) return _lastArtPath;
    final String? path = await cache.cache(art);
    _lastArtUri = art.toString();
    _lastArtPath = path ?? '';
    return _lastArtPath;
  }

  /// Reset the widget to its empty "nothing playing" state.
  Future<void> clear() async {
    _lastArtUri = null;
    _lastArtPath = '';
    try {
      await _client.saveBool(kNpKeyHasTrack, false);
      await _client.saveString(kNpKeyTitle, '');
      await _client.saveString(kNpKeyArtist, '');
      await _client.saveBool(kNpKeyPlaying, false);
      await _client.saveString(kNpKeyArtPath, '');
      await _client.update();
    } catch (e, st) {
      debugPrint('now_playing_widget: clear failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }
}
