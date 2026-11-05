import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/jam.dart';
import '../services/backend_service.dart';

part 'jam_remote.g.dart';

const Duration _kDefaultJamRemotePollInterval = Duration(seconds: 2);

/// Guest state-poll cadence. Overridable for `fake_async` tests.
@Riverpod(keepAlive: true)
Duration jamRemotePollInterval(JamRemotePollIntervalRef ref) =>
    _kDefaultJamRemotePollInterval;

/// The host session this phone is controlling. [hostState] is the latest
/// `GET /jam/{id}/state` snapshot (null until the first poll lands).
class JamRemoteStatus {
  const JamRemoteStatus({
    required this.sessionId,
    required this.hostUsername,
    this.hostState,
  });

  final String sessionId;
  final String hostUsername;
  final JamState? hostState;
}

/// Phase JM guest side. While joined, the play / queue wrappers in
/// `player/playback_actions.dart` send commands here instead of touching the
/// local player, and the host's snapshot is polled every
/// [jamRemotePollInterval] (paused while the app is backgrounded). A host
/// that stops the session flips `ended`, which leaves automatically.
/// `null` state = not joined.
@Riverpod(keepAlive: true)
class JamRemote extends _$JamRemote with WidgetsBindingObserver {
  Timer? _timer;
  bool _observing = false;

  @override
  JamRemoteStatus? build() {
    ref.onDispose(_stopPolling);
    return null;
  }

  /// Throws [ApiError] (e.g. `NotFoundError` for a wrong / ended code).
  Future<void> join(String code) async {
    final BackendService backend = await ref.read(
      backendServiceProvider.future,
    );
    final JamJoin j = await backend.jamJoin(code.trim());
    state = JamRemoteStatus(sessionId: j.id, hostUsername: j.hostUsername);
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    await _tick();
  }

  void leave() {
    _stopPolling();
    state = null;
  }

  /// Send one command to the host. Throws [ApiError]; a 404 means the host
  /// ended the session, so the guest leaves.
  Future<void> send(String kind, [Map<String, dynamic>? payload]) async {
    final JamRemoteStatus? s = state;
    if (s == null) return;
    final BackendService backend = await ref.read(
      backendServiceProvider.future,
    );
    await backend.jamSend(s.sessionId, kind, payload ?? <String, dynamic>{});
  }

  @override
  // `state` would shadow the notifier's own `state`.
  // ignore: avoid_renaming_method_parameters
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (state == null) return;
    if (lifecycle == AppLifecycleState.resumed) {
      _timer?.cancel();
      _tick();
    } else if (lifecycle == AppLifecycleState.paused) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
  }

  Future<void> _tick() async {
    final JamRemoteStatus? s = state;
    if (s == null) return;
    try {
      final BackendService backend = await ref.read(
        backendServiceProvider.future,
      );
      final JamState st = await backend.jamState(s.sessionId);
      if (state?.sessionId != s.sessionId) return; // left mid-flight
      if (st.ended) {
        leave();
        return;
      }
      state = JamRemoteStatus(
        sessionId: s.sessionId,
        hostUsername: s.hostUsername,
        hostState: st,
      );
    } catch (_) {
      // Transient (tailnet blip): keep the last snapshot, keep polling.
      if (state?.sessionId != s.sessionId) return;
    }
    _timer = Timer(ref.read(jamRemotePollIntervalProvider), _tick);
  }
}
