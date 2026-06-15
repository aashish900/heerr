import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/player/sleep_timer.dart';

void main() {
  group('SleepTimerController', () {
    test('starts idle (remaining == null)', () {
      final SleepTimerController c =
          SleepTimerController(onExpire: () async {});
      expect(c.remaining, isNull);
      c.dispose();
    });

    test('setDuration(positive) sets remaining and starts ticking', () {
      fakeAsync((FakeAsync async) {
        int expireCalls = 0;
        final SleepTimerController c = SleepTimerController(
          onExpire: () async {
            expireCalls++;
          },
        );

        c.setDuration(const Duration(seconds: 5));
        expect(c.remaining, const Duration(seconds: 5));

        async.elapse(const Duration(seconds: 1));
        expect(c.remaining, const Duration(seconds: 4));

        async.elapse(const Duration(seconds: 3));
        expect(c.remaining, const Duration(seconds: 1));
        expect(expireCalls, 0);

        c.dispose();
      });
    });

    test('expiry fires onExpire once and clears remaining', () {
      fakeAsync((FakeAsync async) {
        int expireCalls = 0;
        final SleepTimerController c = SleepTimerController(
          onExpire: () async {
            expireCalls++;
          },
        );

        c.setDuration(const Duration(seconds: 2));
        async.elapse(const Duration(seconds: 2));
        expect(c.remaining, isNull);
        expect(expireCalls, 1);

        async.elapse(const Duration(seconds: 30));
        expect(expireCalls, 1, reason: 'no further ticks after expiry');

        c.dispose();
      });
    });

    test('setDuration(null) cancels mid-countdown without firing onExpire',
        () {
      fakeAsync((FakeAsync async) {
        int expireCalls = 0;
        final SleepTimerController c = SleepTimerController(
          onExpire: () async {
            expireCalls++;
          },
        );

        c.setDuration(const Duration(seconds: 10));
        async.elapse(const Duration(seconds: 3));
        expect(c.remaining, const Duration(seconds: 7));

        c.setDuration(null);
        expect(c.remaining, isNull);

        async.elapse(const Duration(seconds: 30));
        expect(expireCalls, 0);

        c.dispose();
      });
    });

    test('cancel() is sugar for setDuration(null)', () {
      fakeAsync((FakeAsync async) {
        int expireCalls = 0;
        final SleepTimerController c = SleepTimerController(
          onExpire: () async {
            expireCalls++;
          },
        );

        c.setDuration(const Duration(seconds: 10));
        c.cancel();
        expect(c.remaining, isNull);

        async.elapse(const Duration(seconds: 30));
        expect(expireCalls, 0);

        c.dispose();
      });
    });

    test('setDuration replaces an active timer (resets the countdown)',
        () {
      fakeAsync((FakeAsync async) {
        int expireCalls = 0;
        final SleepTimerController c = SleepTimerController(
          onExpire: () async {
            expireCalls++;
          },
        );

        c.setDuration(const Duration(seconds: 10));
        async.elapse(const Duration(seconds: 4));
        expect(c.remaining, const Duration(seconds: 6));

        c.setDuration(const Duration(seconds: 20));
        expect(c.remaining, const Duration(seconds: 20));

        async.elapse(const Duration(seconds: 5));
        expect(c.remaining, const Duration(seconds: 15));
        expect(expireCalls, 0);

        c.dispose();
      });
    });

    test('non-positive duration is treated as cancel', () {
      fakeAsync((FakeAsync async) {
        int expireCalls = 0;
        final SleepTimerController c = SleepTimerController(
          onExpire: () async {
            expireCalls++;
          },
        );

        c.setDuration(Duration.zero);
        expect(c.remaining, isNull);

        c.setDuration(const Duration(seconds: -5));
        expect(c.remaining, isNull);

        async.elapse(const Duration(seconds: 30));
        expect(expireCalls, 0);

        c.dispose();
      });
    });

    test('stream emits each remaining-time change exactly once', () {
      fakeAsync((FakeAsync async) {
        final List<Duration?> events = <Duration?>[];
        final SleepTimerController c =
            SleepTimerController(onExpire: () async {});
        c.stream.listen(events.add);

        c.setDuration(const Duration(seconds: 3));
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        expect(events, <Duration?>[
          const Duration(seconds: 3),
          const Duration(seconds: 2),
          const Duration(seconds: 1),
          null,
        ]);

        c.dispose();
      });
    });

    test('exception from onExpire is swallowed', () {
      fakeAsync((FakeAsync async) {
        final SleepTimerController c = SleepTimerController(
          onExpire: () async => throw StateError('boom'),
        );

        c.setDuration(const Duration(seconds: 1));
        // Must not throw.
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(c.remaining, isNull);

        c.dispose();
      });
    });

    test('dispose stops ticking and ignores further setDuration', () {
      fakeAsync((FakeAsync async) {
        int expireCalls = 0;
        final SleepTimerController c = SleepTimerController(
          onExpire: () async {
            expireCalls++;
          },
        );

        c.setDuration(const Duration(seconds: 5));
        unawaited(c.dispose());

        c.setDuration(const Duration(seconds: 1));
        async.elapse(const Duration(seconds: 30));
        expect(expireCalls, 0);
      });
    });
  });
}
