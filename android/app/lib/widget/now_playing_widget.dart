// Named `client` param kept public (not `_client`) so the call site reads
// cleanly; same trade-off as now_playing_persistence.dart.
// ignore_for_file: prefer_initializing_formals

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

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
  NowPlayingWidgetUpdater({required HomeWidgetClient client})
      : _client = client;

  final HomeWidgetClient _client;

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
      await _client.update();
    } catch (e, st) {
      debugPrint('now_playing_widget: push failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  /// Reset the widget to its empty "nothing playing" state.
  Future<void> clear() async {
    try {
      await _client.saveBool(kNpKeyHasTrack, false);
      await _client.saveString(kNpKeyTitle, '');
      await _client.saveString(kNpKeyArtist, '');
      await _client.saveBool(kNpKeyPlaying, false);
      await _client.update();
    } catch (e, st) {
      debugPrint('now_playing_widget: clear failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }
}
