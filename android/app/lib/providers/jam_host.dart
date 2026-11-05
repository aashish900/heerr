import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';

import '../models/jam.dart';
import '../models/subsonic/song.dart';
import '../player/heerr_audio_handler.dart';
import '../player/jam_executor.dart';
import '../player/play_core.dart';
import '../player/player_provider.dart';
import '../services/backend_service.dart';
import 'server_creds.dart';

part 'jam_host.g.dart';

const Duration _kDefaultJamHostPollInterval = Duration(seconds: 1);

/// Long-poll hold for `POST /jam/{id}/sync` (under dio's 10s receiveTimeout).
const double kJamLongPollWaitS = 8;

/// Gap between back-to-back long-polls; also stops a tight loop if a server
/// ever answers instantly.
const Duration _kLoopGap = Duration(milliseconds: 100);

/// Coalesces bursts of player events into one state push.
const Duration _kPushDebounce = Duration(milliseconds: 150);

/// Retry delay after a failed sync. Overridable for `fake_async` tests.
@Riverpod(keepAlive: true)
Duration jamHostPollInterval(JamHostPollIntervalRef ref) =>
    _kDefaultJamHostPollInterval;

/// A live session hosted by this phone. [error] is the last sync failure
/// (cleared on the next success) so the screen can show "reconnecting".
class JamHostStatus {
  const JamHostStatus({
    required this.sessionId,
    required this.code,
    this.commandsReceived = 0,
    this.error,
  });

  final String sessionId;
  final String code;
  final int commandsReceived;
  final Object? error;

  JamHostStatus copyWith({int? commandsReceived, Object? error}) =>
      JamHostStatus(
        sessionId: sessionId,
        code: code,
        commandsReceived: commandsReceived ?? this.commandsReceived,
        error: error,
      );
}

/// Phase JM host side. While a session is live:
/// * a continuous `POST /jam/{id}/sync` long-poll ([kJamLongPollWaitS]) pulls
///   guest commands the moment they are sent and runs them strictly in
///   order, each awaited (the handler's `_isLoadingSource` guard drops
///   overlapping loads); retry after [jamHostPollInterval] on failure;
/// * every meaningful player change (track, play/pause, queue, seek) is
///   pushed via `PUT /jam/{id}/state` so guests see it at once.
/// `null` state = not hosting.
@Riverpod(keepAlive: true)
class JamHost extends _$JamHost {
  Timer? _timer;
  Timer? _pushTimer;
  StreamSubscription<void>? _playerSub;
  int? _cursor;
  ({String key, int positionMs, int atMs, bool playing})? _pushed;

  @override
  JamHostStatus? build() {
    ref.onDispose(_stopLoops);
    return null;
  }

  Future<void> start() async {
    _stopLoops();
    final BackendService backend = await ref.read(
      backendServiceProvider.future,
    );
    final JamSession js = await backend.jamCreate();
    _cursor = null; // bootstrap: skip anything sent before we polled
    _pushed = null;
    state = JamHostStatus(sessionId: js.id, code: js.code);
    final HeerrAudioHandler h = ref.read(audioHandlerProvider);
    _playerSub = Rx.merge<void>(<Stream<void>>[
      h.mediaItem.stream.map((_) {}),
      h.playbackState.stream.map((_) {}),
      h.queue.stream.map((_) {}),
    ]).listen((_) => _onPlayerChanged());
    await _tick();
  }

  Future<void> stop() async {
    _stopLoops();
    final JamHostStatus? s = state;
    state = null;
    if (s == null) return;
    try {
      final BackendService backend = await ref.read(
        backendServiceProvider.future,
      );
      await backend.jamEnd(s.sessionId);
    } catch (_) {
      // Best effort: the 12h TTL ends it server-side anyway.
    }
  }

  void _stopLoops() {
    _timer?.cancel();
    _timer = null;
    _pushTimer?.cancel();
    _pushTimer = null;
    _playerSub?.cancel();
    _playerSub = null;
  }

  Map<String, dynamic> _snapshot(HeerrAudioHandler h, int nowMs) =>
      jamHostState(
        current: h.mediaItem.value,
        playback: h.playbackState.value,
        queue: h.queue.value,
        nowMs: nowMs,
      );

  /// Records what guests now know, so [_onPlayerChanged] only pushes real
  /// changes.
  void _markPushed(HeerrAudioHandler h, int nowMs) {
    final PlaybackState ps = h.playbackState.value;
    _pushed = (
      key: _changeKey(h),
      positionMs: ps.position.inMilliseconds,
      atMs: nowMs,
      playing: ps.playing,
    );
  }

  String _changeKey(HeerrAudioHandler h) {
    final PlaybackState ps = h.playbackState.value;
    return '${h.mediaItem.value?.id}|${ps.playing}|${ps.queueIndex}|'
        '${h.queue.value.length}';
  }

  /// True when guests' view (last pushed snapshot, extrapolated) no longer
  /// matches the player: new track / play state / queue, or a seek.
  bool _differsFromPushed(HeerrAudioHandler h, int now) {
    final ({String key, int positionMs, int atMs, bool playing})? last =
        _pushed;
    if (last == null || last.key != _changeKey(h)) return true;
    final int expected =
        last.positionMs + (last.playing ? now - last.atMs : 0);
    return (h.playbackState.value.position.inMilliseconds - expected).abs() >
        2000;
  }

  void _onPlayerChanged() {
    final JamHostStatus? s = state;
    if (s == null) return;
    final HeerrAudioHandler h = ref.read(audioHandlerProvider);
    if (!_differsFromPushed(h, DateTime.now().millisecondsSinceEpoch)) return;
    _pushTimer?.cancel();
    _pushTimer = Timer(_kPushDebounce, () => _push(s.sessionId));
  }

  Future<void> _push(String sessionId) async {
    if (state?.sessionId != sessionId) return;
    final HeerrAudioHandler h = ref.read(audioHandlerProvider);
    final int now = DateTime.now().millisecondsSinceEpoch;
    // A sync may have carried this state meanwhile.
    if (!_differsFromPushed(h, now)) return;
    _markPushed(h, now);
    try {
      final BackendService backend = await ref.read(
        backendServiceProvider.future,
      );
      await backend.jamPushState(sessionId, _snapshot(h, now));
    } catch (_) {
      // The next sync carries the state anyway.
    }
  }

  Future<void> _tick() async {
    final JamHostStatus? s = state;
    if (s == null) return;
    Duration next = _kLoopGap;
    try {
      final BackendService backend = await ref.read(
        backendServiceProvider.future,
      );
      final HeerrAudioHandler handler = ref.read(audioHandlerProvider);
      final int now = DateTime.now().millisecondsSinceEpoch;
      _markPushed(handler, now);
      final JamSyncResponse r = await backend.jamSync(
        s.sessionId,
        state: _snapshot(handler, now),
        after: _cursor,
        waitS: _cursor == null ? 0 : kJamLongPollWaitS,
      );
      if (state?.sessionId != s.sessionId) return; // stopped mid-flight
      if (r.ended) {
        _stopLoops();
        state = null;
        return;
      }
      for (final JamCommand c in r.commands) {
        try {
          await runJamCommand(c, handler, _toItem);
        } catch (_) {
          // One bad command (e.g. stream URL build failed) must not wedge
          // the cursor; skip it.
        }
      }
      _cursor = r.cursor;
      if (state?.sessionId != s.sessionId) return;
      state = s.copyWith(
        commandsReceived: s.commandsReceived + r.commands.length,
      );
    } catch (e) {
      if (state?.sessionId != s.sessionId) return;
      state = s.copyWith(error: e);
      next = ref.read(jamHostPollIntervalProvider);
    }
    _timer = Timer(next, _tick);
  }
  Future<MediaItem> _toItem(Song song) {
    final ServerCreds c = ref.read(serverCredsProvider);
    return songItem(
      ref.read,
      song,
      url: c.navidromeBaseUrl ?? '',
      user: c.navidromeUsername ?? '',
      pass: c.navidromePassword ?? '',
    );
  }
}
