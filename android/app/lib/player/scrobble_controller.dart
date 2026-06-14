// `prefer_initializing_formals` would force the named constructor parameters
// to be private-prefixed (`_mediaItemStream` etc.), leaking the internal name
// across the public call site. Aliasing in the initializer list is cleaner.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:audio_service/audio_service.dart';

/// Action invoked when the controller wants to record a scrobble event.
/// `submission=false` is the Subsonic "now playing" notification (fired at
/// track start); `submission=true` is the actual scrobble (fired once at
/// ≥ 50% of track duration). Implementations must not throw — exceptions are
/// caught + swallowed inside the controller, but a fast `Future.error` keeps
/// the stream handler clean.
typedef ScrobbleCall = Future<void> Function(
  String subsonicId, {
  required bool submission,
});

/// Plain Dart driver for Subsonic `scrobble.view` integration (Android N1).
///
/// Subscribes to the audio handler's `mediaItem.stream` (track changes) and
/// the underlying player's `positionStream` (playback progress), and:
///
///   - on every new track (distinct `extras['subsonicId']`): fires
///     `scrobble(id, submission=false)` exactly once.
///   - when playback position reaches ≥ 50% of the track's duration: fires
///     `scrobble(id, submission=true)` exactly once *per play*. Seeks past
///     and back across the threshold do not re-fire; only a track change
///     resets the guard.
///
/// MediaItems without a `subsonicId` extra (local playback that bypassed
/// the Subsonic mapping, e.g. malformed entries) are silently skipped — no
/// `submission=false` fires, no submission tracking happens.
///
/// Tests own the streams via `StreamController` and capture every
/// `ScrobbleCall` invocation; production code wires this to the real
/// `HeerrAudioHandler` + `subsonicDioClientProvider` via `scrobbleProvider`.
class ScrobbleController {
  ScrobbleController({
    required Stream<MediaItem?> mediaItemStream,
    required Stream<Duration> positionStream,
    required ScrobbleCall scrobble,
  })  : _mediaItemStream = mediaItemStream,
        _positionStream = positionStream,
        _scrobble = scrobble;

  final Stream<MediaItem?> _mediaItemStream;
  final Stream<Duration> _positionStream;
  final ScrobbleCall _scrobble;

  StreamSubscription<MediaItem?>? _itemSub;
  StreamSubscription<Duration>? _posSub;

  // The Subsonic id of the currently-tracked play, or null when nothing is
  // playing / the item lacks a subsonic id.
  String? _currentSubsonicId;
  Duration? _currentDuration;
  bool _submissionFired = false;

  void start() {
    _itemSub = _mediaItemStream.listen(_onMediaItem);
    _posSub = _positionStream.listen(_onPosition);
  }

  Future<void> dispose() async {
    await _itemSub?.cancel();
    await _posSub?.cancel();
    _itemSub = null;
    _posSub = null;
  }

  Future<void> _onMediaItem(MediaItem? item) async {
    if (item == null) {
      _currentSubsonicId = null;
      _currentDuration = null;
      _submissionFired = false;
      return;
    }

    final String? subsonicId = _subsonicIdFor(item);
    if (subsonicId == null) {
      _currentSubsonicId = null;
      _currentDuration = item.duration;
      _submissionFired = false;
      return;
    }

    // Same track re-emitted (e.g. duration hydrated after load). Don't
    // re-fire the now-playing notification, but absorb the latest duration
    // in case it just became available.
    if (subsonicId == _currentSubsonicId) {
      _currentDuration = item.duration ?? _currentDuration;
      return;
    }

    _currentSubsonicId = subsonicId;
    _currentDuration = item.duration;
    _submissionFired = false;

    try {
      await _scrobble(subsonicId, submission: false);
    } catch (_) {
      // Scrobbling is best-effort; never propagate failures into the stream.
    }
  }

  Future<void> _onPosition(Duration position) async {
    if (_submissionFired) return;
    final String? subsonicId = _currentSubsonicId;
    final Duration? duration = _currentDuration;
    if (subsonicId == null || duration == null) return;
    if (duration.inMilliseconds <= 0) return;
    if (position.inMilliseconds * 2 < duration.inMilliseconds) return;

    _submissionFired = true;
    try {
      await _scrobble(subsonicId, submission: true);
    } catch (_) {
      // Best-effort; the submission flag stays set so we don't retry
      // mid-play. The next track resets it.
    }
  }

  static String? _subsonicIdFor(MediaItem item) {
    final dynamic raw = item.extras?['subsonicId'];
    if (raw is String && raw.isNotEmpty) return raw;
    return null;
  }
}
