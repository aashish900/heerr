import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/prefs_storage.dart';
import '../providers/server_creds.dart';
import 'offline_manifest.dart';

part 'offline_settings.g.dart';

/// The five offline-download preferences.
///
/// A6: this notifier is now the *sole* owner of the offline prefs. Before A6
/// the prefs were read by a `Settings` provider and re-sliced here; `Settings`
/// is gone and this notifier reads/writes [PrefsStorage] directly. Credentials
/// live under [serverCredsProvider] (A1/A6) — they are no longer co-mingled
/// with these prefs, so toggling a pref here doesn't rebuild credential
/// consumers (and vice-versa).
typedef OfflineSettingsValue = ({
  bool enabled,
  bool syncAll,
  bool wifiOnly,
  int pollIntervalMinutes,
  // Q2: background-sync constraint. Gates the periodic worker on the device
  // being plugged in. Has no effect on the foreground sync timer.
  bool chargingOnly,
});

const String _kKeyOfflineEnabled = 'offline_enabled';
const String _kKeyOfflineSyncAll = 'offline_sync_all';
const String _kKeyOfflineWifiOnly = 'offline_wifi_only';
const String _kKeyOfflinePollIntervalMin = 'offline_poll_interval_min';
const String _kKeyOfflineChargingOnly = 'offline_charging_only';

// Defaults applied at build-time when the corresponding prefs key is
// missing. Master switch ships OFF so existing installs keep streaming;
// WiFi-only ships ON so a thumb-fumble can't burn cellular data.
const bool _kDefaultOfflineEnabled = false;
const bool _kDefaultOfflineSyncAll = false;
const bool _kDefaultOfflineWifiOnly = true;
const int _kDefaultOfflinePollIntervalMin = 15;
const bool _kDefaultOfflineChargingOnly = false;

@Riverpod(keepAlive: true)
class OfflineSettings extends _$OfflineSettings {
  @override
  Future<OfflineSettingsValue> build() async {
    // A4/A5: non-secret prefs read from plain prefs in one concurrent batch
    // instead of ten sequential keystore round-trips.
    final PrefsStorage prefs = ref.watch(prefsStorageProvider);
    final List<String?> off = await Future.wait(<Future<String?>>[
      prefs.read(_kKeyOfflineEnabled),
      prefs.read(_kKeyOfflineSyncAll),
      prefs.read(_kKeyOfflineWifiOnly),
      prefs.read(_kKeyOfflinePollIntervalMin),
      prefs.read(_kKeyOfflineChargingOnly),
    ]);
    return (
      enabled: _parseBool(off[0], _kDefaultOfflineEnabled),
      syncAll: _parseBool(off[1], _kDefaultOfflineSyncAll),
      wifiOnly: _parseBool(off[2], _kDefaultOfflineWifiOnly),
      pollIntervalMinutes: _parseInt(off[3], _kDefaultOfflinePollIntervalMin),
      chargingOnly: _parseBool(off[4], _kDefaultOfflineChargingOnly),
    );
  }

  Future<void> setEnabled(bool value) async {
    await _write(_kKeyOfflineEnabled, value.toString());
  }

  Future<void> setSyncAll(bool value) async {
    // Snapshot creds + the manifest store BEFORE the write. Otherwise the
    // write invalidates this notifier, it is marked for rebuild, and any
    // further `ref.read` here trips the "dependency changed before rebuild"
    // assertion. Server-key fields (navidromeBaseUrl/Username) don't change,
    // so the snapshot is safe.
    final ServerCreds creds = ref.read(serverCredsProvider);
    final OfflineManifestStore store =
        await ref.read(offlineManifestStoreProvider.future);
    await _write(_kKeyOfflineSyncAll, value.toString());
    // Per L4 spec: flipping syncAll invalidates the preflight estimate cache
    // even though the estimate value itself doesn't depend on syncAll. Keeps
    // the cache rule uniform with marker mutations.
    await _clearEstimateCacheFor(creds, store);
  }

  Future<void> setWifiOnly(bool value) async {
    await _write(_kKeyOfflineWifiOnly, value.toString());
  }

  Future<void> setPollInterval(int minutes) async {
    await _write(_kKeyOfflinePollIntervalMin, minutes.toString());
  }

  Future<void> setChargingOnly(bool value) async {
    await _write(_kKeyOfflineChargingOnly, value.toString());
  }

  Future<void> _write(String key, String value) async {
    final PrefsStorage prefs = ref.read(prefsStorageProvider);
    await prefs.write(key, value);
    ref.invalidateSelf();
  }

  Future<void> _clearEstimateCacheFor(
    ServerCreds creds,
    OfflineManifestStore store,
  ) async {
    if (creds.navidromeBaseUrl == null) return;
    final OfflineManifest m = await store.load(creds);
    if (m.estimatedTotalBytes == null && m.estimatedAt == null) return;
    await store.save(
      creds,
      m.copyWith(estimatedTotalBytes: null, estimatedAt: null),
    );
    // ref.invalidate is safe here — invalidate doesn't trip the
    // "dependency-outdated" assertion (it just marks a sibling provider).
    ref.invalidate(offlineManifestProvider);
  }
}

bool _parseBool(String? raw, bool fallback) {
  if (raw == null) return fallback;
  if (raw == 'true') return true;
  if (raw == 'false') return false;
  return fallback;
}

int _parseInt(String? raw, int fallback) {
  if (raw == null) return fallback;
  return int.tryParse(raw) ?? fallback;
}
