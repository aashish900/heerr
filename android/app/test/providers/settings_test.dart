import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/profile.dart';
import 'package:heerr/providers/prefs_storage.dart';
import 'package:heerr/providers/profiles/active_profile.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/providers/settings.dart';

/// In-memory fake implementing BOTH storage interfaces. A1/A5 split the
/// settings state across two stores — credentials live in the profile
/// registry (Android EncryptedSharedPreferences via [SecureStorage]); the
/// offline prefs moved to plain [PrefsStorage]. The two interfaces share the
/// same read/write/delete shape, so one fake backs both providers and the
/// `snapshot` assertions stay store-agnostic.
class _FakeStore implements SecureStorage, PrefsStorage {
  _FakeStore([Map<String, String>? seed])
    : _data = <String, String>{...?seed};

  final Map<String, String> _data;

  Map<String, String> get snapshot => Map<String, String>.unmodifiable(_data);

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}

ProviderContainer _makeContainer(_FakeStore fake, {Profile? active}) {
  return ProviderContainer(
    overrides: <Override>[
      secureStorageProvider.overrideWith((Ref<SecureStorage> ref) => fake),
      prefsStorageProvider.overrideWith((Ref<PrefsStorage> ref) => fake),
      if (active != null)
        activeProfileProvider.overrideWith((Ref<Profile?> ref) => active),
    ],
  );
}

Profile _profile() {
  final DateTime t = DateTime.utc(2026, 6, 19);
  return Profile(
    id: 'p1',
    displayName: 'me',
    heerrBaseUrl: 'http://100.x.y.z:8000/api/v1',
    heerrBearerToken: 'raw-token-xyz',
    navidromeBaseUrl: 'http://100.x.y.z:4533',
    navidromeUsername: 'me',
    navidromePassword: 'navi-pw',
    createdAt: t,
    lastUsedAt: t,
  );
}

void main() {
  group('Settings provider — credentials from active profile (A1)', () {
    test('no active profile → all cred fields null + offline defaults',
        () async {
      final _FakeStore fake = _FakeStore();
      final ProviderContainer c = _makeContainer(fake);
      addTearDown(c.dispose);

      final SettingsValue v = await c.read(settingsProvider.future);

      expect(v.backendBaseUrl, isNull);
      expect(v.bearerToken, isNull);
      expect(v.navidromeBaseUrl, isNull);
      expect(v.navidromeUsername, isNull);
      expect(v.navidromePassword, isNull);
      // L1 defaults: master OFF, sync-all OFF, WiFi-only ON, 15-min poll.
      expect(v.offlineEnabled, isFalse);
      expect(v.offlineSyncAll, isFalse);
      expect(v.offlineWifiOnly, isTrue);
      expect(v.offlinePollIntervalMin, 15);
      expect(v.offlineChargingOnly, isFalse);
    });

    test('active profile → all credential fields mirror it', () async {
      final _FakeStore fake = _FakeStore();
      final ProviderContainer c = _makeContainer(fake, active: _profile());
      addTearDown(c.dispose);

      final SettingsValue v = await c.read(settingsProvider.future);

      expect(v.backendBaseUrl, 'http://100.x.y.z:8000/api/v1');
      expect(v.bearerToken, 'raw-token-xyz');
      expect(v.navidromeBaseUrl, 'http://100.x.y.z:4533');
      expect(v.navidromeUsername, 'me');
      expect(v.navidromePassword, 'navi-pw');
    });
  });

  group('Settings provider — offline prefs (A5: plain prefs)', () {
    test('save(offline fields) round-trip through storage', () async {
      final _FakeStore fake = _FakeStore();
      final ProviderContainer c = _makeContainer(fake);
      addTearDown(c.dispose);

      await c.read(settingsProvider.future);
      await c.read(settingsProvider.notifier).save(
            offlineEnabled: true,
            offlineSyncAll: true,
            offlineWifiOnly: false,
            offlinePollIntervalMin: 30,
          );

      final SettingsValue v = await c.read(settingsProvider.future);
      expect(v.offlineEnabled, isTrue);
      expect(v.offlineSyncAll, isTrue);
      expect(v.offlineWifiOnly, isFalse);
      expect(v.offlinePollIntervalMin, 30);
      expect(fake.snapshot, <String, String>{
        'offline_enabled': 'true',
        'offline_sync_all': 'true',
        'offline_wifi_only': 'false',
        'offline_poll_interval_min': '30',
      });
    });

    test('save(offlineEnabled only) preserves other offline keys + defaults',
        () async {
      final _FakeStore fake = _FakeStore(<String, String>{
        'offline_wifi_only': 'false',
        'offline_poll_interval_min': '60',
      });
      final ProviderContainer c = _makeContainer(fake);
      addTearDown(c.dispose);

      await c.read(settingsProvider.future);
      await c.read(settingsProvider.notifier).save(offlineEnabled: true);

      final SettingsValue v = await c.read(settingsProvider.future);
      expect(v.offlineEnabled, isTrue);
      // Untouched seed values stay; sync-all wasn't seeded, so it
      // falls back to the L1 default (false).
      expect(v.offlineWifiOnly, isFalse);
      expect(v.offlinePollIntervalMin, 60);
      expect(v.offlineSyncAll, isFalse);
    });

    test('save(offlineChargingOnly) round-trips through storage', () async {
      // Q2: background-sync charging-only constraint.
      final _FakeStore fake = _FakeStore();
      final ProviderContainer c = _makeContainer(fake);
      addTearDown(c.dispose);

      final SettingsValue defaults = await c.read(settingsProvider.future);
      expect(defaults.offlineChargingOnly, isFalse);

      await c.read(settingsProvider.notifier).save(offlineChargingOnly: true);

      final SettingsValue v = await c.read(settingsProvider.future);
      expect(v.offlineChargingOnly, isTrue);
      expect(fake.snapshot, <String, String>{
        'offline_charging_only': 'true',
      });
    });

    test('save with all null is a no-op (does not delete existing values)',
        () async {
      final _FakeStore fake = _FakeStore(<String, String>{
        'offline_enabled': 'true',
      });
      final ProviderContainer c = _makeContainer(fake);
      addTearDown(c.dispose);

      await c.read(settingsProvider.future);
      await c.read(settingsProvider.notifier).save();

      expect(fake.snapshot, <String, String>{'offline_enabled': 'true'});
    });

    test('clear() wipes offline keys and re-emits defaults', () async {
      final _FakeStore fake = _FakeStore(<String, String>{
        'offline_enabled': 'true',
        'offline_sync_all': 'true',
        'offline_wifi_only': 'false',
        'offline_poll_interval_min': '60',
        'offline_charging_only': 'true',
      });
      final ProviderContainer c = _makeContainer(fake);
      addTearDown(c.dispose);

      await c.read(settingsProvider.future);
      await c.read(settingsProvider.notifier).clear();

      final SettingsValue v = await c.read(settingsProvider.future);
      expect(v.offlineEnabled, isFalse);
      expect(v.offlineSyncAll, isFalse);
      expect(v.offlineWifiOnly, isTrue);
      expect(v.offlinePollIntervalMin, 15);
      expect(v.offlineChargingOnly, isFalse);
      expect(fake.snapshot, isEmpty);
    });

    test('clear() leaves credentials untouched (profile-owned)', () async {
      // clear() is offline-only; the active profile's creds survive it.
      final _FakeStore fake = _FakeStore(<String, String>{
        'offline_enabled': 'true',
      });
      final ProviderContainer c = _makeContainer(fake, active: _profile());
      addTearDown(c.dispose);

      await c.read(settingsProvider.future);
      await c.read(settingsProvider.notifier).clear();

      final SettingsValue v = await c.read(settingsProvider.future);
      expect(v.bearerToken, 'raw-token-xyz');
      expect(v.offlineEnabled, isFalse);
    });

    test('corrupt offline value in storage → falls back to default', () async {
      // Seeded keys that aren't 'true' / 'false' / int — the value parser
      // must not crash; it returns the L1 default.
      final _FakeStore fake = _FakeStore(<String, String>{
        'offline_enabled': 'maybe',
        'offline_poll_interval_min': 'fifteen',
      });
      final ProviderContainer c = _makeContainer(fake);
      addTearDown(c.dispose);

      final SettingsValue v = await c.read(settingsProvider.future);
      expect(v.offlineEnabled, isFalse);
      expect(v.offlinePollIntervalMin, 15);
    });
  });
}
