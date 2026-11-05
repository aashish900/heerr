import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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

/// Host sync cadence. Overridable for `fake_async` tests.
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

/// Phase JM host side: while a session is live, every [jamHostPollInterval]
/// push the player snapshot and pull guest commands via `POST /jam/{id}/sync`,
/// then run them strictly in order, each awaited (the handler's
/// `_isLoadingSource` guard drops overlapping loads). One-shot `Timer`
/// rescheduled after each tick (same shape as `queue.dart`), so ticks never
/// overlap. `null` state = not hosting.
@Riverpod(keepAlive: true)
class JamHost extends _$JamHost {
  Timer? _timer;
  int? _cursor;

  @override
  JamHostStatus? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  Future<void> start() async {
    _timer?.cancel();
    final BackendService backend = await ref.read(
      backendServiceProvider.future,
    );
    final JamSession js = await backend.jamCreate();
    _cursor = null; // bootstrap: skip anything sent before we polled
    state = JamHostStatus(sessionId: js.id, code: js.code);
    await _tick();
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
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

  Future<void> _tick() async {
    final JamHostStatus? s = state;
    if (s == null) return;
    try {
      final BackendService backend = await ref.read(
        backendServiceProvider.future,
      );
      final HeerrAudioHandler handler = ref.read(audioHandlerProvider);
      final JamSyncResponse r = await backend.jamSync(
        s.sessionId,
        state: jamHostState(
          current: handler.mediaItem.value,
          playback: handler.playbackState.value,
          queue: handler.queue.value,
          nowMs: DateTime.now().millisecondsSinceEpoch,
        ),
        after: _cursor,
      );
      if (state?.sessionId != s.sessionId) return; // stopped mid-flight
      if (r.ended) {
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
    }
    _timer = Timer(ref.read(jamHostPollIntervalProvider), _tick);
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
