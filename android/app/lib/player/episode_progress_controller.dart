// `prefer_initializing_formals` would force the named constructor parameters
// to be private-prefixed, leaking the internal name across the public call
// site. Same pattern as `scrobble_controller.dart`.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:audio_service/audio_service.dart';

import 'episode_to_media_item.dart';

/// Action invoked to persist an episode's playback position.
/// `played=true` is reserved for a future completion signal — this
/// controller always reports `false`; the backend/UI otherwise treats a
/// position report as "still in progress." Implementations must not throw —
/// exceptions are caught + swallowed inside the controller, mirroring
/// [ScrobbleCall]'s contract.
typedef EpisodeProgressCall = Future<void> Function(
  String episodeId,
  int positionS, {
  required bool played,
});

/// Plain Dart driver for podcast episode resume-position sync (PC5, #53).
///
/// Subscribes to the audio handler's `mediaItem.stream` (track changes),
/// `player.positionStream` (playback progress), and `playbackState.stream`
/// (play/pause transitions), and:
///
///   - while an episode is the current track and playing, fires
///     [report] at most once every [minInterval] (default 15s) as the
///     position stream ticks.
///   - fires [report] immediately (bypassing the throttle) when playback
///     pauses/stops, or when the track changes away from the episode —
///     both report the last known position for that episode.
///
/// Non-episode `MediaItem`s (library songs, previews) are ignored entirely
/// — [isEpisodeMediaItem] gates every report.
///
/// Tests own the streams via `StreamController`s and capture every
/// [EpisodeProgressCall] invocation; production code wires this to the real
/// `HeerrAudioHandler` + `BackendService` via `episodeProgressProvider`.
class EpisodeProgressController {
  EpisodeProgressController({
    required Stream<MediaItem?> mediaItemStream,
    required Stream<Duration> positionStream,
    required Stream<PlaybackState> playbackStateStream,
    required EpisodeProgressCall report,
    Duration minInterval = const Duration(seconds: 15),
    DateTime Function() now = DateTime.now,
  })  : _mediaItemStream = mediaItemStream,
        _positionStream = positionStream,
        _playbackStateStream = playbackStateStream,
        _report = report,
        _minInterval = minInterval,
        _now = now;

  final Stream<MediaItem?> _mediaItemStream;
  final Stream<Duration> _positionStream;
  final Stream<PlaybackState> _playbackStateStream;
  final EpisodeProgressCall _report;
  final Duration _minInterval;
  final DateTime Function() _now;

  StreamSubscription<MediaItem?>? _itemSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<PlaybackState>? _stateSub;

  String? _currentEpisodeId;
  Duration _lastPosition = Duration.zero;
  DateTime? _lastReportAt;
  bool _wasPlaying = false;

  void start() {
    _itemSub = _mediaItemStream.listen(_onMediaItem);
    _posSub = _positionStream.listen(_onPosition);
    _stateSub = _playbackStateStream.listen(_onPlaybackState);
  }

  Future<void> dispose() async {
    await _itemSub?.cancel();
    await _posSub?.cancel();
    await _stateSub?.cancel();
    _itemSub = null;
    _posSub = null;
    _stateSub = null;
  }

  Future<void> _onMediaItem(MediaItem? item) async {
    final String? previous = _currentEpisodeId;
    if (previous != null) {
      await _fire(previous, force: true);
    }
    _currentEpisodeId = isEpisodeMediaItem(item) ? episodeIdFromMediaItem(item) : null;
    _lastPosition = Duration.zero;
    _lastReportAt = null;
    _wasPlaying = false;
  }

  Future<void> _onPosition(Duration position) async {
    _lastPosition = position;
    if (_currentEpisodeId == null) return;
    await _fire(_currentEpisodeId!, force: false);
  }

  Future<void> _onPlaybackState(PlaybackState state) async {
    final String? episodeId = _currentEpisodeId;
    if (episodeId != null && _wasPlaying && !state.playing) {
      await _fire(episodeId, force: true);
    }
    _wasPlaying = state.playing;
  }

  Future<void> _fire(String episodeId, {required bool force}) async {
    final DateTime nowT = _now();
    if (!force) {
      final DateTime? last = _lastReportAt;
      if (last != null && nowT.difference(last) < _minInterval) return;
    }
    _lastReportAt = nowT;
    try {
      await _report(episodeId, _lastPosition.inSeconds, played: false);
    } catch (_) {
      // Best-effort, mirrors ScrobbleController — never break playback.
    }
  }
}
