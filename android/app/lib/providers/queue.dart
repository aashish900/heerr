import 'dart:async';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api/client.dart';
import '../api/endpoints.dart';
import '../models/queue_response.dart';

part 'queue.g.dart';

const Duration _kDefaultQueuePollInterval = Duration(seconds: 3);

/// Polling interval for `GET /queue`. Exposed as a provider so tests can
/// override it (typically to a short real duration when paired with
/// `fake_async`).
@Riverpod(keepAlive: true)
Duration queuePollInterval(QueuePollIntervalRef ref) =>
    _kDefaultQueuePollInterval;

/// Polls `GET /queue` on a schedule (PLAN.md §8 — 3s default, pauses on app
/// background). Implemented as an `AsyncNotifier` rather than a
/// `StreamProvider` because the UI needs to **imperatively** pause/resume on
/// lifecycle changes — Streams don't expose that control to consumers.
///
/// `keepAlive: true` so the in-progress poll cycle survives screen rebuilds
/// (e.g. quickly switching tabs and back).
@Riverpod(keepAlive: true)
class Queue extends _$Queue {
  Timer? _timer;
  bool _paused = false;

  @override
  Future<QueueResponse> build() async {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    final QueueResponse first = await _fetch();
    _scheduleNext();
    return first;
  }

  /// Cancel the pending tick. The screen calls this when the app moves to
  /// the background.
  void pause() {
    if (_paused) return;
    _paused = true;
    _timer?.cancel();
    _timer = null;
  }

  /// Force a fetch immediately and resume the periodic schedule. The screen
  /// calls this when the app returns to the foreground.
  Future<void> resume() async {
    if (!_paused) return;
    _paused = false;
    await _tick();
  }

  void _scheduleNext() {
    if (_paused) return;
    _timer?.cancel();
    final Duration interval = ref.read(queuePollIntervalProvider);
    _timer = Timer(interval, _tick);
  }

  Future<void> _tick() async {
    if (_paused) return;
    state = await AsyncValue.guard(_fetch);
    // Reschedule even on failure — transient errors shouldn't stop polling.
    _scheduleNext();
  }

  Future<QueueResponse> _fetch() async {
    final Dio dio = await ref.read(dioClientProvider.future);
    return apiCall<QueueResponse>(
      () => dio.get<dynamic>(Endpoints.queue),
      (dynamic data) => QueueResponse.fromJson(data as Map<String, dynamic>),
    );
  }
}
