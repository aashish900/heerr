import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/profile.dart';
import 'prefs_storage.dart';
import 'profiles/active_profile.dart';

part 'settings.g.dart';

/// Active backend + Navidrome credentials and the five offline-download
/// preferences.
///
/// Credentials are sourced exclusively from the active [Profile] (Phase S);
/// the pre-S single-set secure-storage keys are gone (A1). The offline
/// preferences are plain user prefs and live in [PrefsStorage] /
/// `shared_preferences`, not EncryptedSharedPreferences (A5). All credential
/// fields are nullable so a fresh install (no active profile yet) is
/// representable; the offline fields always carry a value via the defaults
/// applied in [Settings.build].
typedef SettingsValue = ({
  String? backendBaseUrl,
  String? bearerToken,
  String? navidromeBaseUrl,
  String? navidromeUsername,
  String? navidromePassword,
  bool offlineEnabled,
  bool offlineSyncAll,
  bool offlineWifiOnly,
  int offlinePollIntervalMin,
  // Q2: background-sync constraint. When true, the WorkManager constraint
  // requires the device to be charging before the periodic worker runs.
  // Default false — most users want overnight sync regardless of charger
  // state, and WiFi-only already protects against cellular spend.
  bool offlineChargingOnly,
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

@riverpod
class Settings extends _$Settings {
  @override
  Future<SettingsValue> build() async {
    // A1: the active Profile is the sole source for every per-server
    // credential. There is no legacy single-set-key fallback any more —
    // unmigrated installs are handled by `migrateLegacyCreds` (S3) before
    // the first `runApp`, and a null active profile means the router
    // redirect (S5) has already sent the user to /login. Watching the
    // profile keeps every existing serverKey-hashing chokepoint (L1/L5/P1)
    // wired to the active identity without per-callsite rewiring.
    final Profile? active = ref.watch(activeProfileProvider);

    // A5: offline prefs are non-secret — read them from plain prefs. A4:
    // one provider read + a single concurrent batch instead of ten
    // sequential `await store.read(...)` calls against the keystore.
    final PrefsStorage prefs = ref.watch(prefsStorageProvider);
    final List<String?> off = await Future.wait(<Future<String?>>[
      prefs.read(_kKeyOfflineEnabled),
      prefs.read(_kKeyOfflineSyncAll),
      prefs.read(_kKeyOfflineWifiOnly),
      prefs.read(_kKeyOfflinePollIntervalMin),
      prefs.read(_kKeyOfflineChargingOnly),
    ]);

    return (
      backendBaseUrl: active?.heerrBaseUrl,
      bearerToken: active?.heerrBearerToken,
      navidromeBaseUrl: active?.navidromeBaseUrl,
      navidromeUsername: active?.navidromeUsername,
      navidromePassword: active?.navidromePassword,
      offlineEnabled: _parseBool(off[0], _kDefaultOfflineEnabled),
      offlineSyncAll: _parseBool(off[1], _kDefaultOfflineSyncAll),
      offlineWifiOnly: _parseBool(off[2], _kDefaultOfflineWifiOnly),
      offlinePollIntervalMin: _parseInt(off[3], _kDefaultOfflinePollIntervalMin),
      offlineChargingOnly: _parseBool(off[4], _kDefaultOfflineChargingOnly),
    );
  }

  /// Persist any subset of the offline preferences. Credentials are no
  /// longer writable here — they are owned by the profile registry and set
  /// at login (S5) — so this method only carries the offline fields.
  Future<void> save({
    bool? offlineEnabled,
    bool? offlineSyncAll,
    bool? offlineWifiOnly,
    int? offlinePollIntervalMin,
    bool? offlineChargingOnly,
  }) async {
    final PrefsStorage prefs = ref.read(prefsStorageProvider);
    if (offlineEnabled != null) {
      await prefs.write(_kKeyOfflineEnabled, offlineEnabled.toString());
    }
    if (offlineSyncAll != null) {
      await prefs.write(_kKeyOfflineSyncAll, offlineSyncAll.toString());
    }
    if (offlineWifiOnly != null) {
      await prefs.write(_kKeyOfflineWifiOnly, offlineWifiOnly.toString());
    }
    if (offlinePollIntervalMin != null) {
      await prefs.write(
        _kKeyOfflinePollIntervalMin,
        offlinePollIntervalMin.toString(),
      );
    }
    if (offlineChargingOnly != null) {
      await prefs.write(
        _kKeyOfflineChargingOnly,
        offlineChargingOnly.toString(),
      );
    }
    ref.invalidateSelf();
  }

  /// Reset the offline preferences to their defaults. Profile credentials
  /// are not touched — those are managed via the profile registry (remove
  /// the active profile from Settings to drop credentials).
  Future<void> clear() async {
    final PrefsStorage prefs = ref.read(prefsStorageProvider);
    await prefs.delete(_kKeyOfflineEnabled);
    await prefs.delete(_kKeyOfflineSyncAll);
    await prefs.delete(_kKeyOfflineWifiOnly);
    await prefs.delete(_kKeyOfflinePollIntervalMin);
    await prefs.delete(_kKeyOfflineChargingOnly);
    ref.invalidateSelf();
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
