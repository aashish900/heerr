import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/settings.dart';
import 'offline_manifest.dart';

part 'offline_settings.g.dart';

/// Typed view of the four offline-related preferences stored on the global
/// `SettingsValue`. Same shape as `SettingsValue` for the offline fields,
/// but exposed as its own record so consumers (UI sections, the sync
/// provider) can `watch` just this slice without rebuilding on credential
/// changes.
typedef OfflineSettingsValue = ({
  bool enabled,
  bool syncAll,
  bool wifiOnly,
  int pollIntervalMinutes,
  // Q2: background-sync constraint. Gates the periodic worker on the device
  // being plugged in. Has no effect on the foreground sync timer.
  bool chargingOnly,
});

@Riverpod(keepAlive: true)
class OfflineSettings extends _$OfflineSettings {
  @override
  Future<OfflineSettingsValue> build() async {
    final SettingsValue s = await ref.watch(settingsProvider.future);
    return (
      enabled: s.offlineEnabled,
      syncAll: s.offlineSyncAll,
      wifiOnly: s.offlineWifiOnly,
      pollIntervalMinutes: s.offlinePollIntervalMin,
      chargingOnly: s.offlineChargingOnly,
    );
  }

  Future<void> setEnabled(bool value) async {
    await ref.read(settingsProvider.notifier).save(offlineEnabled: value);
  }

  Future<void> setSyncAll(bool value) async {
    // Snapshot settings + the manifest store BEFORE the save. Otherwise the
    // save invalidates settingsProvider, this notifier (which watches it) is
    // marked for rebuild, and any further `ref.read` here trips the
    // "dependency changed before rebuild" assertion. Server-key fields
    // (navidromeBaseUrl/Username) don't change, so the snapshot is safe.
    final SettingsValue settings =
        await ref.read(settingsProvider.future);
    final OfflineManifestStore store =
        await ref.read(offlineManifestStoreProvider.future);
    await ref.read(settingsProvider.notifier).save(offlineSyncAll: value);
    // Per L4 spec: flipping syncAll invalidates the preflight estimate cache
    // even though the estimate value itself doesn't depend on syncAll. Keeps
    // the cache rule uniform with marker mutations.
    await _clearEstimateCacheFor(settings, store);
  }

  Future<void> setWifiOnly(bool value) async {
    await ref.read(settingsProvider.notifier).save(offlineWifiOnly: value);
  }

  Future<void> setPollInterval(int minutes) async {
    await ref
        .read(settingsProvider.notifier)
        .save(offlinePollIntervalMin: minutes);
  }

  Future<void> setChargingOnly(bool value) async {
    await ref
        .read(settingsProvider.notifier)
        .save(offlineChargingOnly: value);
  }

  Future<void> _clearEstimateCacheFor(
    SettingsValue settings,
    OfflineManifestStore store,
  ) async {
    if (settings.navidromeBaseUrl == null) return;
    final OfflineManifest m = await store.load(settings);
    if (m.estimatedTotalBytes == null && m.estimatedAt == null) return;
    await store.save(
      settings,
      m.copyWith(estimatedTotalBytes: null, estimatedAt: null),
    );
    // ref.invalidate is safe here — invalidate doesn't trip the
    // "dependency-outdated" assertion (it just marks a sibling provider).
    ref.invalidate(offlineManifestProvider);
  }
}
