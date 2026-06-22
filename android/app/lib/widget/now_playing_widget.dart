// Named `client` param kept public (not `_client`) so the call site reads
// cleanly; same trade-off as now_playing_persistence.dart.
// ignore_for_file: prefer_initializing_formals

import 'package:audio_service/audio_service.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import '../player/heerr_audio_handler.dart';
import '../utils/palette.dart';

/// #20: home-screen "Now Playing" widget.
///
/// A compact single-row tile: track title + artist, a play/pause / next /
/// previous control row, and a (display-only) progress bar. Controls are
/// wired natively in [NowPlayingWidgetProvider.kt] as `ACTION_MEDIA_BUTTON`
/// broadcasts to `com.ryanheise.audioservice.MediaButtonReceiver`, so they
/// drive the **live** audio_service MediaSession — no background isolate, no
/// second player instance.
///
/// Deliberately renders no cover art: a RemoteViews layout that decodes
/// bitmaps from disk on every track change was the source of repeated
/// blank-widget / race bugs (see DEBT.md #20). This Dart side only pushes
/// lightweight display state; the native provider name + these data keys are
/// the contract the RemoteViews reads.

/// Must match the Kotlin `AppWidgetProvider` class (and its manifest
/// `<receiver android:name>`).
const String kNowPlayingWidgetName = 'NowPlayingWidgetProvider';

const String kNpKeyHasTrack = 'np_has_track';
const String kNpKeyTitle = 'np_title';
const String kNpKeyArtist = 'np_artist';
const String kNpKeyPlaying = 'np_playing';

/// Cover-derived background tint as a **signed 32-bit ARGB int**, stored as a
/// decimal string (empty when none). Signed so it fits Kotlin's `Int` —
/// `0xFF......` as an unsigned value overflows `Int.toIntOrNull`. The native
/// side paints the tile background this colour; no bitmaps involved.
const String kNpKeyTintArgb = 'np_tint_argb';

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
  Future<void> update() => HomeWidget.updateWidget(
        name: kNowPlayingWidgetName,
        androidName: kNowPlayingWidgetName,
      );
}

/// Maps a [PlayerSnapshot] onto the widget's data keys and asks the OS to
/// redraw. All failures are swallowed — a missing-platform / no-widget-added
/// error must never break playback.
class NowPlayingWidgetUpdater {
  NowPlayingWidgetUpdater({
    required HomeWidgetClient client,
    WidgetTintExtractor? tintExtractor,
  })  : _client = client,
        _tint = tintExtractor;

  final HomeWidgetClient _client;
  final WidgetTintExtractor? _tint;

  // Per-track guard: the cover (and thus tint) only changes on track change,
  // so we don't recompute the palette on every play/pause/position emission.
  String? _lastTintUri;
  String _lastTint = '';

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
      await _client.update();
    } catch (e, st) {
      debugPrint('now_playing_widget: push failed: $e');
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

  /// Reset the widget to its empty "nothing playing" state.
  Future<void> clear() async {
    _lastTintUri = null;
    _lastTint = '';
    try {
      await _client.saveBool(kNpKeyHasTrack, false);
      await _client.saveString(kNpKeyTitle, '');
      await _client.saveString(kNpKeyArtist, '');
      await _client.saveBool(kNpKeyPlaying, false);
      await _client.saveString(kNpKeyTintArgb, '');
      await _client.update();
    } catch (e, st) {
      debugPrint('now_playing_widget: clear failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }
}
