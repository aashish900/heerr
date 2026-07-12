import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/offline/offline_sync.dart';
import 'package:heerr/providers/server_creds.dart';
import 'package:heerr/providers/server_status.dart';
import 'package:heerr/screens/settings/server_sync_card.dart';
import 'package:heerr/theme.dart';

const OfflineSyncStatus _kIdleSynced = (
  running: false,
  targetCount: 10,
  readyCount: 10,
  failedCount: 0,
  lastError: null,
  lastTickAt: null,
);

/// Fake [ServerStatusNotifier] returning a fixed [ServerStatus] without
/// touching the real backend-health probe or its 30s Timer.
class _FakeServerStatus extends ServerStatusNotifier {
  _FakeServerStatus(this._value);
  final ServerStatus _value;

  @override
  Future<ServerStatus> build() async => _value;
}

/// Fake [OfflineSync] that skips the real build chain (profile/settings/
/// manifest/Wi-Fi wiring) and lets tests control `syncNow()` + busy state.
class _FakeOfflineSync extends OfflineSync {
  _FakeOfflineSync(this._value, {this.onSyncNow});
  final OfflineSyncStatus _value;
  final Future<OfflineSyncResult> Function()? onSyncNow;

  @override
  Future<OfflineSyncStatus> build() async => _value;

  @override
  Future<OfflineSyncResult> syncNow() async {
    if (onSyncNow != null) return onSyncNow!();
    return (downloadedCount: 0, failedCount: 0, sweptCount: 0, error: null);
  }
}

Widget _wrap(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: heerrDarkTheme(),
      home: const Scaffold(body: ServerSyncCard()),
    ),
  );
}

void main() {
  group('ServerSyncCard', () {
    testWidgets('online + synced state renders hostname, Online pill, last sync', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(<Override>[
        serverCredsProvider.overrideWithValue(
          (navidromeBaseUrl: 'http://myhost.ts.net', navidromeUsername: 'u', navidromePassword: 'p'),
        ),
        serverStatusNotifierProvider.overrideWith(
          () => _FakeServerStatus((online: true, errorMessage: null, checkedAt: DateTime.now())),
        ),
        offlineSyncProvider.overrideWith(() => _FakeOfflineSync(_kIdleSynced)),
      ]));
      await tester.pump();
      await tester.pump();

      expect(find.text('Online'), findsOneWidget);
      expect(find.textContaining('myhost.ts.net'), findsOneWidget);
      expect(find.text('Sync now'), findsOneWidget);
    });

    testWidgets('offline state renders Offline pill and unreachable caption', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(<Override>[
        serverCredsProvider.overrideWithValue(
          (navidromeBaseUrl: 'http://myhost.ts.net', navidromeUsername: 'u', navidromePassword: 'p'),
        ),
        serverStatusNotifierProvider.overrideWith(
          () => _FakeServerStatus((online: false, errorMessage: 'Backend reported unhealthy', checkedAt: DateTime.now())),
        ),
        offlineSyncProvider.overrideWith(() => _FakeOfflineSync(_kIdleSynced)),
      ]));
      await tester.pump();
      await tester.pump();

      expect(find.text('Offline'), findsOneWidget);
      expect(find.textContaining('unreachable'), findsOneWidget);
    });

    testWidgets('never-synced state shows "Not synced yet"', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(<Override>[
        serverCredsProvider.overrideWithValue(
          (navidromeBaseUrl: 'http://myhost.ts.net', navidromeUsername: 'u', navidromePassword: 'p'),
        ),
        serverStatusNotifierProvider.overrideWith(
          () => _FakeServerStatus((online: true, errorMessage: null, checkedAt: DateTime.now())),
        ),
        offlineSyncProvider.overrideWith(() => _FakeOfflineSync(
              const (
                running: false,
                targetCount: 0,
                readyCount: 0,
                failedCount: 0,
                lastError: null,
                lastTickAt: null,
              ),
            )),
      ]));
      await tester.pump();
      await tester.pump();

      expect(find.text('Not synced yet'), findsOneWidget);
    });

    testWidgets('Sync Now tap fires syncNow and disables while running', (
      WidgetTester tester,
    ) async {
      bool called = false;
      await tester.pumpWidget(_wrap(<Override>[
        serverCredsProvider.overrideWithValue(
          (navidromeBaseUrl: 'http://myhost.ts.net', navidromeUsername: 'u', navidromePassword: 'p'),
        ),
        serverStatusNotifierProvider.overrideWith(
          () => _FakeServerStatus((online: true, errorMessage: null, checkedAt: DateTime.now())),
        ),
        offlineSyncProvider.overrideWith(() => _FakeOfflineSync(
              _kIdleSynced,
              onSyncNow: () async {
                called = true;
                return (downloadedCount: 2, failedCount: 0, sweptCount: 0, error: null);
              },
            )),
      ]));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Sync now'));
      await tester.pump();

      expect(called, isTrue);
    });
  });
}
