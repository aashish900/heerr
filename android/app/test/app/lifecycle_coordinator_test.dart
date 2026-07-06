import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/recommended_track.dart';
import 'package:heerr/offline/offline_sync.dart';
import 'package:heerr/providers/recommendations.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/router.dart';
import 'package:heerr/theme.dart';

// A8: lifecycle forwarding moved out of _ShellScaffold into
// LifecycleCoordinator. These tests assert the coordinator still forwards
// AppLifecycleState transitions into pause()/resume() on the sync notifier.
// They drive it through the real router so the ShellRoute composition
// (LifecycleCoordinator wrapping the shell) is exercised end-to-end.

class _NoopStorage implements SecureStorage {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

class _StubSync extends OfflineSync {
  int pauseCalls = 0;
  int resumeCalls = 0;

  void resetCounts() {
    pauseCalls = 0;
    resumeCalls = 0;
  }

  @override
  Future<OfflineSyncStatus> build() async {
    return (
      running: false,
      targetCount: 0,
      readyCount: 0,
      failedCount: 0,
      lastError: null,
      lastTickAt: null,
    );
  }

  @override
  void pause() {
    pauseCalls += 1;
  }

  @override
  Future<void> resume() async {
    resumeCalls += 1;
  }

  @override
  Future<OfflineSyncResult> syncNow() async {
    return (downloadedCount: 0, failedCount: 0, sweptCount: 0, error: null);
  }
}

class _StubRecs extends Recommendations {
  int refreshIfStaleCalls = 0;

  @override
  Future<List<RecommendedTrack>> build() async => const <RecommendedTrack>[];

  @override
  void refreshIfStale({Duration maxAge = const Duration(minutes: 30)}) {
    refreshIfStaleCalls += 1;
  }
}

void main() {
  Future<void> sendLifecycle(WidgetTester tester, String state) async {
    final ByteData? msg = const StringCodec().encodeMessage(state);
    await tester.binding.defaultBinaryMessenger
        .handlePlatformMessage('flutter/lifecycle', msg, (_) {});
  }

  Widget boot(_StubSync stub) {
    return ProviderScope(
      overrides: <Override>[
        secureStorageProvider
            .overrideWith((Ref<SecureStorage> _) => _NoopStorage()),
        offlineSyncProvider.overrideWith(() => stub),
      ],
      child: MaterialApp.router(
        theme: heerrDarkTheme(),
        routerConfig: buildHeerrRouter(),
      ),
    );
  }

  testWidgets('paused → calls pause() on OfflineSync', (
    WidgetTester tester,
  ) async {
    final _StubSync stub = _StubSync();
    await tester.pumpWidget(boot(stub));
    await tester.pumpAndSettle();
    // The init microtask may pre-touch the provider — we only care about
    // counts AFTER the lifecycle event.
    stub.resetCounts();

    await sendLifecycle(tester, 'AppLifecycleState.paused');
    await tester.pumpAndSettle();

    expect(stub.pauseCalls, greaterThanOrEqualTo(1));
    expect(stub.resumeCalls, 0);
  });

  testWidgets('resumed → calls resume() on OfflineSync', (
    WidgetTester tester,
  ) async {
    final _StubSync stub = _StubSync();
    await tester.pumpWidget(boot(stub));
    await tester.pumpAndSettle();
    stub.resetCounts();

    await sendLifecycle(tester, 'AppLifecycleState.resumed');
    await tester.pumpAndSettle();

    expect(stub.resumeCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('resumed → calls refreshIfStale() on Recommendations (#38)', (
    WidgetTester tester,
  ) async {
    final _StubSync sync = _StubSync();
    final _StubRecs recs = _StubRecs();
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        secureStorageProvider
            .overrideWith((Ref<SecureStorage> _) => _NoopStorage()),
        offlineSyncProvider.overrideWith(() => sync),
        recommendationsProvider.overrideWith(() => recs),
      ],
      child: MaterialApp.router(
        theme: heerrDarkTheme(),
        routerConfig: buildHeerrRouter(),
      ),
    ));
    await tester.pumpAndSettle();
    final int before = recs.refreshIfStaleCalls;

    await sendLifecycle(tester, 'AppLifecycleState.resumed');
    await tester.pumpAndSettle();

    expect(recs.refreshIfStaleCalls, greaterThan(before));
  });
}
