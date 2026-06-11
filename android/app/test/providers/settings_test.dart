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
    test('fresh storage → all fields null', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c = _makeContainer(fake);
      addTearDown(c.dispose);

      final SettingsValue v = await c.read(settingsProvider.future);

      expect(v.backendBaseUrl, isNull);
      expect(v.bearerToken, isNull);
      expect(v.navidromeBaseUrl, isNull);
      expect(v.navidromeUsername, isNull);
      expect(v.navidromePassword, isNull);
    });

    test('pre-seeded storage → values are loaded (heerr + navidrome)', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage(<String, String>{
        'backend_base_url': 'http://100.106.120.121:8000/api/v1',
        'bearer_token': 'raw-token-xyz',
        'navidrome_base_url': 'http://100.106.120.121:4533',
        'navidrome_username': 'me',
        'navidrome_password': 'navi-pw',
      });
      final ProviderContainer c = _makeContainer(fake);
      addTearDown(c.dispose);

      final SettingsValue v = await c.read(settingsProvider.future);

      expect(v.backendBaseUrl, 'http://100.106.120.121:8000/api/v1');
      expect(v.bearerToken, 'raw-token-xyz');
      expect(v.navidromeBaseUrl, 'http://100.106.120.121:4533');
      expect(v.navidromeUsername, 'me');
      expect(v.navidromePassword, 'navi-pw');
    });

    test('pre-seeded storage with only heerr fields → navidrome stays null', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage(<String, String>{
        'backend_base_url': 'http://x:8000/api/v1',
        'bearer_token': 't',
      });
      final ProviderContainer c = _makeContainer(fake);
      addTearDown(c.dispose);

      final SettingsValue v = await c.read(settingsProvider.future);

      expect(v.backendBaseUrl, 'http://x:8000/api/v1');
      expect(v.bearerToken, 't');
      expect(v.navidromeBaseUrl, isNull);
      expect(v.navidromeUsername, isNull);
      expect(v.navidromePassword, isNull);
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

    test('clear() wipes all 5 keys and re-emits null state', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage(<String, String>{
        'backend_base_url': 'http://x:8000/api/v1',
        'bearer_token': 't',
        'navidrome_base_url': 'http://navi:4533',
        'navidrome_username': 'me',
        'navidrome_password': 'pw',
      });
      final ProviderContainer c = _makeContainer(fake);
      addTearDown(c.dispose);

      await c.read(settingsProvider.future);
      await c.read(settingsProvider.notifier).clear();

      final SettingsValue v = await c.read(settingsProvider.future);
      expect(v.backendBaseUrl, isNull);
      expect(v.bearerToken, isNull);
      expect(v.navidromeBaseUrl, isNull);
      expect(v.navidromeUsername, isNull);
      expect(v.navidromePassword, isNull);
      expect(fake.snapshot, isEmpty);
    });

    test('save(navidrome fields) persists them without touching heerr fields',
        () async {
      final _FakeSecureStorage fake = _FakeSecureStorage(<String, String>{
        'backend_base_url': 'http://x:8000/api/v1',
        'bearer_token': 't',
      });
      final ProviderContainer c = _makeContainer(fake);
      addTearDown(c.dispose);

      await c.read(settingsProvider.future);
      await c.read(settingsProvider.notifier).save(
            navidromeBaseUrl: 'http://navi:4533',
            navidromeUsername: 'me',
            navidromePassword: 'pw',
          );

      final SettingsValue v = await c.read(settingsProvider.future);
      expect(v.backendBaseUrl, 'http://x:8000/api/v1');
      expect(v.bearerToken, 't');
      expect(v.navidromeBaseUrl, 'http://navi:4533');
      expect(v.navidromeUsername, 'me');
      expect(v.navidromePassword, 'pw');
      expect(fake.snapshot, <String, String>{
        'backend_base_url': 'http://x:8000/api/v1',
        'bearer_token': 't',
        'navidrome_base_url': 'http://navi:4533',
        'navidrome_username': 'me',
        'navidrome_password': 'pw',
      });
    });

    test('save(navidromeUsername only) updates just that key', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage(<String, String>{
        'navidrome_base_url': 'http://navi:4533',
        'navidrome_username': 'old-user',
        'navidrome_password': 'pw',
      });
      final ProviderContainer c = _makeContainer(fake);
      addTearDown(c.dispose);

      await c.read(settingsProvider.future);
      await c
          .read(settingsProvider.notifier)
          .save(navidromeUsername: 'new-user');

      final SettingsValue v = await c.read(settingsProvider.future);
      expect(v.navidromeUsername, 'new-user');
      expect(v.navidromeBaseUrl, 'http://navi:4533');
      expect(v.navidromePassword, 'pw');
    });
  });

  group('ServerProfile JSON round-trip', () {
    test('full profile (heerr + navidrome) round-trips', () {
      const ServerProfile p = ServerProfile(
        name: 'Home',
        backendBaseUrl: 'http://x:8000/api/v1',
        bearerToken: 't',
        navidromeBaseUrl: 'http://navi:4533',
        navidromeUsername: 'me',
        navidromePassword: 'pw',
      );
      final ServerProfile back = ServerProfile.fromJson(
        Map<String, dynamic>.from(p.toJson()),
      );
      expect(back.name, p.name);
      expect(back.backendBaseUrl, p.backendBaseUrl);
      expect(back.bearerToken, p.bearerToken);
      expect(back.navidromeBaseUrl, p.navidromeBaseUrl);
      expect(back.navidromeUsername, p.navidromeUsername);
      expect(back.navidromePassword, p.navidromePassword);
    });

    test('legacy profile JSON (heerr only) loads with null navidrome fields',
        () {
      // Stored profiles written before H1 won't have the new keys at all.
      final ServerProfile back = ServerProfile.fromJson(<String, dynamic>{
        'name': 'Old',
        'backendBaseUrl': 'http://x:8000/api/v1',
        'bearerToken': 't',
      });
      expect(back.name, 'Old');
      expect(back.navidromeBaseUrl, isNull);
      expect(back.navidromeUsername, isNull);
      expect(back.navidromePassword, isNull);
    });
  });
}
