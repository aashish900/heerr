// `prefer_initializing_formals` would force the public named constructor
// params to be private-prefixed (`_onExpire`, `_now`), leaking the
// internal names across the call site. Same pattern as
// `scrobble_controller.dart`.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'player_provider.dart';

part 'sleep_timer.g.dart';

/// Tick interval — externalised for tests that want to drive a faster
/// clock without standing up `fake_async`.
const Duration _kSleepTimerTick = Duration(seconds: 1);

/// Fires when the sleep timer reaches zero. Implementations should call
/// the audio handler's pause method. Exceptions are caught + swallowed
/// by the controller — sleep is best-effort and should never crash the
/// player.
typedef SleepTimerExpire = Future<void> Function();

/// Plain-Dart sleep-timer controller. P3.
///
/// State machine:
///   - idle: [remaining] is null, no timer running.
///   - active: [remaining] is non-null, a `Timer.periodic` ticks every
///     [tick] and decrements.
///   - on expiry: cancels the timer, sets remaining to null, calls
///     [onExpire] exactly once.
///
/// [setDuration] is the one-shot way to set, replace, or cancel:
///   - null / Duration.zero / negative → cancel.
///   - positive → start (or restart) the countdown.
///
/// Listeners subscribe to [stream] (broadcast) for `remaining` updates
/// (one event per state change, including the initial null → active
/// transition and the active → null expiry). For Riverpod consumers,
/// [SleepTimerNotifier] adapts the controller to the standard notifier
/// shape.
class SleepTimerController {
  SleepTimerController({
    required SleepTimerExpire onExpire,
    Duration tick = _kSleepTimerTick,
  })  : _onExpire = onExpire,
        _tick = tick;

  final SleepTimerExpire _onExpire;
  final Duration _tick;

  final StreamController<Duration?> _ctrl =
      StreamController<Duration?>.broadcast();

  Duration? _remaining;
  Timer? _timer;
  bool _disposed = false;

  /// Current remaining time. Null when idle.
  Duration? get remaining => _remaining;

  /// Broadcast stream of remaining-time changes. Useful for tests; the
  /// Riverpod notifier wraps `state` instead.
  Stream<Duration?> get stream => _ctrl.stream;

  void setDuration(Duration? duration) {
    if (_disposed) return;
    _timer?.cancel();
    _timer = null;
    if (duration == null || duration <= Duration.zero) {
      _emit(null);
      return;
    }
    _emit(duration);
    _timer = Timer.periodic(_tick, (_) => _onTick());
  }

  void cancel() => setDuration(null);

  void _onTick() {
    final Duration? r = _remaining;
    if (r == null) return;
    final Duration next = r - _tick;
    if (next <= Duration.zero) {
      _timer?.cancel();
      _timer = null;
      _emit(null);
      // Attach the handler before the future is returned so async errors
      // from `_onExpire` don't propagate out into the timer callback /
      // FakeAsync zone. `unawaited` on its own doesn't catch — the error
      // would still escape via the microtask queue.
      unawaited(_onExpire().catchError((Object e, StackTrace st) {
        debugPrint('sleep_timer: onExpire threw: $e');
        debugPrintStack(stackTrace: st);
      }));
      return;
    }
    _emit(next);
  }

  void _emit(Duration? value) {
    _remaining = value;
    if (!_ctrl.isClosed) _ctrl.add(value);
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    await _ctrl.close();
  }
}

/// Riverpod-facing notifier. P3. Owns one [SleepTimerController] whose
/// `onExpire` callback resolves [audioHandlerProvider] and calls
/// `pause()`. Survives app background (keep-alive); does not survive
/// cold start (intentional — sleep timers are session-scoped).
@Riverpod(keepAlive: true)
class SleepTimerNotifier extends _$SleepTimerNotifier {
  SleepTimerController? _controller;
  StreamSubscription<Duration?>? _sub;

  @override
  Duration? build() {
    final SleepTimerController controller = SleepTimerController(
      onExpire: () async {
        await ref.read(audioHandlerProvider).pause();
      },
    );
    _controller = controller;
    _sub = controller.stream.listen((Duration? r) {
      state = r;
    });
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
      unawaited(controller.dispose());
      _controller = null;
    });
    return null;
  }

  void setDuration(Duration? duration) {
    _controller?.setDuration(duration);
  }

  void cancel() => setDuration(null);
}
