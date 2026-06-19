import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'secure_storage.dart';

part 'prefs_storage.g.dart';

/// Plain (non-secret) key-value store for user preferences.
///
/// Deliberately mirrors the [SecureStorage] interface so a test fake can
/// implement both and be registered under both providers — see
/// `settings_test.dart`. The offline-download preferences (A5) live here,
/// not in Android EncryptedSharedPreferences: they aren't secrets (the
/// bearer token + Navidrome password are the only secrets, and those live
/// in the per-profile registry), so paying the keystore round-trip on every
/// read was wasteful.
abstract class PrefsStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Production impl backed by `shared_preferences`. The [SharedPreferences]
/// instance is fetched lazily on first access and cached, so the provider
/// can stay synchronous (matching [secureStorageProvider]) without forcing
/// every consumer to await an init future.
class SharedPrefsStorage implements PrefsStorage {
  SharedPreferences? _cached;

  Future<SharedPreferences> get _prefs async =>
      _cached ??= await SharedPreferences.getInstance();

  @override
  Future<String?> read(String key) async => (await _prefs).getString(key);

  @override
  Future<void> write(String key, String value) async =>
      (await _prefs).setString(key, value);

  @override
  Future<void> delete(String key) async => (await _prefs).remove(key);
}

/// Riverpod provider returning the active [PrefsStorage] instance. Tests
/// override with `prefsStorageProvider.overrideWith((ref) => FakePrefs())`.
@riverpod
PrefsStorage prefsStorage(PrefsStorageRef ref) => SharedPrefsStorage();

/// Secure-storage keys that A5 relocates from EncryptedSharedPreferences to
/// plain `shared_preferences`. Kept in one place so [migrateOfflinePrefs]
/// and any future audit share the canonical list.
const List<String> kOfflinePrefKeys = <String>[
  'offline_enabled',
  'offline_sync_all',
  'offline_wifi_only',
  'offline_poll_interval_min',
  'offline_charging_only',
];

/// One-shot migration (A5): copy the offline-download preferences out of
/// [SecureStorage] (where Phases L/Q originally stored them) into plain
/// [PrefsStorage], then delete them from secure storage.
///
/// Idempotent: once the keys are gone from secure storage, re-running is a
/// no-op. Runs in `main.dart` before `runApp`, after [migrateLegacyCreds].
Future<void> migrateOfflinePrefs(ProviderContainer container) async {
  final SecureStorage secure = container.read(secureStorageProvider);
  final PrefsStorage prefs = container.read(prefsStorageProvider);
  for (final String key in kOfflinePrefKeys) {
    final String? value = await secure.read(key);
    if (value == null) continue;
    await prefs.write(key, value);
    await secure.delete(key);
  }
}
