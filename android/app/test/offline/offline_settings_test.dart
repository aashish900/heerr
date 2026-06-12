import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/offline/offline_settings.dart';
import 'package:heerr/providers/secure_storage.dart';

class _FakeSecureStorage implements SecureStorage {
  _FakeSecureStorage([Map<String, String>? seed])
    : _data = <String, String>{...?seed};

  final Map<String, String> _data;

  Map<String, String> get snapshot =>
      Map<String, String>.unmodifiable(_data);

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

ProviderContainer _makeContainer(_FakeSecureStorage fake) {
  return ProviderContainer(
    overrides: <Override>[
      secureStorageProvider.overrideWith((Ref<SecureStorage> ref) => fake),
    ],
  );
}

void main() {
  group('OfflineSettings provider', () {
    test('fresh storage → L1 defaults (off/off/on/15)', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c = _makeContainer(fake);
      addTearDown(c.dispose);

      final OfflineSettingsValue v =
          await c.read(offlineSettingsProvider.future);

      expect(v.enabled, isFalse);
      expect(v.syncAll, isFalse);
      expect(v.wifiOnly, isTrue);
      expect(v.pollIntervalMinutes, 15);
    });

    test('setEnabled(true) persists + re-emits', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c = _makeContainer(fake);
      addTearDown(c.dispose);

      await c.read(offlineSettingsProvider.future);
      await c.read(offlineSettingsProvider.notifier).setEnabled(true);

      final OfflineSettingsValue v =
          await c.read(offlineSettingsProvider.future);
      expect(v.enabled, isTrue);
      expect(fake.snapshot['offline_enabled'], 'true');
    });

    test('setSyncAll(true) persists + re-emits', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c = _makeContainer(fake);
      addTearDown(c.dispose);

      await c.read(offlineSettingsProvider.future);
      await c.read(offlineSettingsProvider.notifier).setSyncAll(true);

      final OfflineSettingsValue v =
          await c.read(offlineSettingsProvider.future);
      expect(v.syncAll, isTrue);
      expect(fake.snapshot['offline_sync_all'], 'true');
    });

    test('setWifiOnly(false) persists + re-emits', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c = _makeContainer(fake);
      addTearDown(c.dispose);

      await c.read(offlineSettingsProvider.future);
      await c.read(offlineSettingsProvider.notifier).setWifiOnly(false);

      final OfflineSettingsValue v =
          await c.read(offlineSettingsProvider.future);
      expect(v.wifiOnly, isFalse);
      expect(fake.snapshot['offline_wifi_only'], 'false');
    });

    test('setPollInterval(60) persists + re-emits', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c = _makeContainer(fake);
      addTearDown(c.dispose);

      await c.read(offlineSettingsProvider.future);
      await c.read(offlineSettingsProvider.notifier).setPollInterval(60);

      final OfflineSettingsValue v =
          await c.read(offlineSettingsProvider.future);
      expect(v.pollIntervalMinutes, 60);
      expect(fake.snapshot['offline_poll_interval_min'], '60');
    });

    test('pre-seeded storage → values flow through', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage(<String, String>{
        'offline_enabled': 'true',
        'offline_sync_all': 'true',
        'offline_wifi_only': 'false',
        'offline_poll_interval_min': '5',
      });
      final ProviderContainer c = _makeContainer(fake);
      addTearDown(c.dispose);

      final OfflineSettingsValue v =
          await c.read(offlineSettingsProvider.future);
      expect(v.enabled, isTrue);
      expect(v.syncAll, isTrue);
      expect(v.wifiOnly, isFalse);
      expect(v.pollIntervalMinutes, 5);
    });
  });
}
