import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/settings.dart';

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
    );
  }

  Future<void> setEnabled(bool value) async {
    await ref.read(settingsProvider.notifier).save(offlineEnabled: value);
  }

  Future<void> setSyncAll(bool value) async {
    await ref.read(settingsProvider.notifier).save(offlineSyncAll: value);
  }

  Future<void> setWifiOnly(bool value) async {
    await ref.read(settingsProvider.notifier).save(offlineWifiOnly: value);
  }

  Future<void> setPollInterval(int minutes) async {
    await ref
        .read(settingsProvider.notifier)
        .save(offlinePollIntervalMin: minutes);
  }
}
