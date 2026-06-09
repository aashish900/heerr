import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/providers/settings.dart';

class _FakeSecureStorage implements SecureStorage {
  _FakeSecureStorage([Map<String, String>? seed])
    : _data = <String, String>{...?seed};

  final Map<String, String> _data;

  // Read so tests can assert what's been written without going through the
  // provider — proves the value actually hit storage, not just cached state.
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

ProviderContainer _makeContainer(_FakeSecureStorage fake) {
  return ProviderContainer(
    overrides: <Override>[
      secureStorageProvider.overrideWith((Ref<SecureStorage> ref) => fake),
    ],
  );
}

void main() {
  group('Settings provider', () {
    test('fresh storage → both fields null', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c = _makeContainer(fake);
      addTearDown(c.dispose);

      final SettingsValue v = await c.read(settingsProvider.future);

      expect(v.backendBaseUrl, isNull);
      expect(v.bearerToken, isNull);
    });

    test('pre-seeded storage → values are loaded', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage(<String, String>{
        'backend_base_url': 'http://100.106.120.121:8000/api/v1',
        'bearer_token': 'raw-token-xyz',
      });
      final ProviderContainer c = _makeContainer(fake);
      addTearDown(c.dispose);

      final SettingsValue v = await c.read(settingsProvider.future);

      expect(v.backendBaseUrl, 'http://100.106.120.121:8000/api/v1');
      expect(v.bearerToken, 'raw-token-xyz');
    });

    test('save(url) writes that field and re-emits the new state', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c = _makeContainer(fake);
      addTearDown(c.dispose);

      // Force initial build.
      await c.read(settingsProvider.future);

      await c
          .read(settingsProvider.notifier)
          .save(backendBaseUrl: 'http://x:8000/api/v1');

      final SettingsValue v = await c.read(settingsProvider.future);
      expect(v.backendBaseUrl, 'http://x:8000/api/v1');
      expect(v.bearerToken, isNull);
      expect(fake.snapshot, <String, String>{
        'backend_base_url': 'http://x:8000/api/v1',
      });
    });

    test('save(token) writes that field without touching url', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage(<String, String>{
        'backend_base_url': 'http://x:8000/api/v1',
      });
      final ProviderContainer c = _makeContainer(fake);
      addTearDown(c.dispose);

      await c.read(settingsProvider.future);
      await c.read(settingsProvider.notifier).save(bearerToken: 'tok-1');

      final SettingsValue v = await c.read(settingsProvider.future);
      expect(v.backendBaseUrl, 'http://x:8000/api/v1');
      expect(v.bearerToken, 'tok-1');
    });

    test('save(both) persists both fields', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c = _makeContainer(fake);
      addTearDown(c.dispose);

      await c.read(settingsProvider.future);
      await c
          .read(settingsProvider.notifier)
          .save(backendBaseUrl: 'http://x:8000/api/v1', bearerToken: 't');

      expect(fake.snapshot, <String, String>{
        'backend_base_url': 'http://x:8000/api/v1',
        'bearer_token': 't',
      });
    });

    test('save with both null is a no-op (does not delete existing values)', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage(<String, String>{
        'backend_base_url': 'http://x:8000/api/v1',
        'bearer_token': 't',
      });
      final ProviderContainer c = _makeContainer(fake);
      addTearDown(c.dispose);

      await c.read(settingsProvider.future);
      await c.read(settingsProvider.notifier).save();

      expect(fake.snapshot, <String, String>{
        'backend_base_url': 'http://x:8000/api/v1',
        'bearer_token': 't',
      });
    });

    test('clear() wipes both keys and re-emits null state', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage(<String, String>{
        'backend_base_url': 'http://x:8000/api/v1',
        'bearer_token': 't',
      });
      final ProviderContainer c = _makeContainer(fake);
      addTearDown(c.dispose);

      await c.read(settingsProvider.future);
      await c.read(settingsProvider.notifier).clear();

      final SettingsValue v = await c.read(settingsProvider.future);
      expect(v.backendBaseUrl, isNull);
      expect(v.bearerToken, isNull);
      expect(fake.snapshot, isEmpty);
    });
  });
}
