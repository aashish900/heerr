import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/offline/offline_manifest.dart';
import 'package:heerr/offline/offline_settings.dart';
import 'package:heerr/offline/offline_sync.dart';
import 'package:heerr/providers/sync_activity.dart';

// DL4 (Downloads "Sync Center" activity row): counts derived from the
// manifest's per-song states + the global Wi-Fi-only gate. Per-song
// titles/byte-progress aren't tracked (D5) so this is count-based.

class _FakeSettings extends OfflineSettings {
  _FakeSettings(this.value);
  final OfflineSettingsValue value;
  @override
  Future<OfflineSettingsValue> build() async => value;
}

class _FakeWifiCheck implements WifiCheck {
  _FakeWifiCheck({required this.onWifi});
  final bool onWifi;
  @override
  Future<bool> isOnWifi() async => onWifi;
  @override
  Stream<bool> get onWifiChanged => const Stream<bool>.empty();
}

const OfflineSettingsValue _kWifiOnlySettings = (
  enabled: true,
  syncAll: false,
  wifiOnly: true,
  pollIntervalMinutes: 15,
  chargingOnly: false,
);

const OfflineSettingsValue _kAnyNetworkSettings = (
  enabled: true,
  syncAll: false,
  wifiOnly: false,
  pollIntervalMinutes: 15,
  chargingOnly: false,
);

OfflineManifest _manifestWith(Map<String, OfflineSongState> states) {
  return OfflineManifest(
    songs: <String, OfflineSongEntry>{
      for (final MapEntry<String, OfflineSongState> e in states.entries)
        e.key: OfflineSongEntry(state: e.value),
    },
  );
}

ProviderContainer _container({
  required OfflineManifest manifest,
  required OfflineSettingsValue settings,
  bool onWifi = true,
}) {
  final ProviderContainer c = ProviderContainer(
    overrides: <Override>[
      offlineManifestProvider.overrideWith((_) async => manifest),
      offlineSettingsProvider.overrideWith(() => _FakeSettings(settings)),
      wifiCheckProvider.overrideWithValue(_FakeWifiCheck(onWifi: onWifi)),
    ],
  );
  return c;
}

void main() {
  test('empty manifest → all-zero, not waiting for wifi', () async {
    final ProviderContainer c = _container(
      manifest: _manifestWith(<String, OfflineSongState>{}),
      settings: _kAnyNetworkSettings,
    );
    addTearDown(c.dispose);

    final SyncActivity a = await c.read(syncActivityProvider.future);

    expect(a.downloadingCount, 0);
    expect(a.queuedCount, 0);
    expect(a.failedCount, 0);
    expect(a.waitingForWifi, isFalse);
  });

  test('counts downloading/queued/failed songs by state', () async {
    final ProviderContainer c = _container(
      manifest: _manifestWith(<String, OfflineSongState>{
        's1': OfflineSongState.downloading,
        's2': OfflineSongState.downloading,
        's3': OfflineSongState.queued,
        's4': OfflineSongState.failed,
        's5': OfflineSongState.ready,
      }),
      settings: _kAnyNetworkSettings,
    );
    addTearDown(c.dispose);

    final SyncActivity a = await c.read(syncActivityProvider.future);

    expect(a.downloadingCount, 2);
    expect(a.queuedCount, 1);
    expect(a.failedCount, 1);
  });

  test('wifiOnly + pending work + not on wifi → waitingForWifi', () async {
    final ProviderContainer c = _container(
      manifest: _manifestWith(<String, OfflineSongState>{
        's1': OfflineSongState.queued,
      }),
      settings: _kWifiOnlySettings,
      onWifi: false,
    );
    addTearDown(c.dispose);

    final SyncActivity a = await c.read(syncActivityProvider.future);

    expect(a.waitingForWifi, isTrue);
  });

  test('wifiOnly but already on wifi → not waiting', () async {
    final ProviderContainer c = _container(
      manifest: _manifestWith(<String, OfflineSongState>{
        's1': OfflineSongState.queued,
      }),
      settings: _kWifiOnlySettings,
      onWifi: true,
    );
    addTearDown(c.dispose);

    final SyncActivity a = await c.read(syncActivityProvider.future);

    expect(a.waitingForWifi, isFalse);
  });

  test('wifiOnly with nothing pending → not waiting (nothing to wait for)',
      () async {
    final ProviderContainer c = _container(
      manifest: _manifestWith(<String, OfflineSongState>{
        's1': OfflineSongState.ready,
        's2': OfflineSongState.failed,
      }),
      settings: _kWifiOnlySettings,
      onWifi: false,
    );
    addTearDown(c.dispose);

    final SyncActivity a = await c.read(syncActivityProvider.future);

    expect(a.waitingForWifi, isFalse);
  });
}
