import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/client.dart';
import 'package:heerr/api/subsonic_client.dart';
import 'package:heerr/models/profile.dart';
import 'package:heerr/providers/profiles/profile_registry.dart';
import 'package:heerr/providers/secure_storage.dart';

class _FakeSecureStorage implements SecureStorage {
  final Map<String, String> _data = <String, String>{};
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

Profile _profile({
  required String id,
  required String heerrBaseUrl,
  required String heerrBearerToken,
  required String navidromeBaseUrl,
  required String navidromeUsername,
  required String navidromePassword,
}) {
  final DateTime t = DateTime.utc(2026, 6, 17, 10, 0, 0);
  return Profile(
    id: id,
    displayName: navidromeUsername,
    heerrBaseUrl: heerrBaseUrl,
    heerrBearerToken: heerrBearerToken,
    navidromeBaseUrl: navidromeBaseUrl,
    navidromeUsername: navidromeUsername,
    navidromePassword: navidromePassword,
    createdAt: t,
    lastUsedAt: t,
  );
}

void main() {
  group('S7 — clients keyed off active profile', () {
    test('heerr dio rebuilds when active profile switches', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          secureStorageProvider
              .overrideWith((Ref<SecureStorage> ref) => fake),
        ],
      );
      addTearDown(c.dispose);

      await c.read(profileRegistryProvider.future);
      final Profile a = _profile(
        id: 'p-a',
        heerrBaseUrl: 'http://a.heerr:8000/api/v1',
        heerrBearerToken: 'tok-a',
        navidromeBaseUrl: 'http://a.nd:4533',
        navidromeUsername: 'alice',
        navidromePassword: 'pw-a',
      );
      final Profile b = _profile(
        id: 'p-b',
        heerrBaseUrl: 'http://b.heerr:8000/api/v1',
        heerrBearerToken: 'tok-b',
        navidromeBaseUrl: 'http://b.nd:4533',
        navidromeUsername: 'bob',
        navidromePassword: 'pw-b',
      );
      await c.read(profileRegistryProvider.notifier).addProfile(a);
      await c.read(profileRegistryProvider.notifier).addProfile(b);
      await c.read(profileRegistryProvider.notifier).setActive(a.id);

      final Dio dioA = await c.read(dioClientProvider.future);
      expect(dioA.options.baseUrl, 'http://a.heerr:8000/api/v1');

      await c.read(profileRegistryProvider.notifier).setActive(b.id);
      final Dio dioB = await c.read(dioClientProvider.future);
      expect(dioB.options.baseUrl, 'http://b.heerr:8000/api/v1');
    });

    test('subsonic dio rebuilds when active profile switches', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          secureStorageProvider
              .overrideWith((Ref<SecureStorage> ref) => fake),
        ],
      );
      addTearDown(c.dispose);

      await c.read(profileRegistryProvider.future);
      final Profile a = _profile(
        id: 'p-a',
        heerrBaseUrl: 'http://a.heerr:8000',
        heerrBearerToken: 'tok-a',
        navidromeBaseUrl: 'http://a.nd:4533',
        navidromeUsername: 'alice',
        navidromePassword: 'pw-a',
      );
      final Profile b = _profile(
        id: 'p-b',
        heerrBaseUrl: 'http://b.heerr:8000',
        heerrBearerToken: 'tok-b',
        navidromeBaseUrl: 'http://b.nd:4533',
        navidromeUsername: 'bob',
        navidromePassword: 'pw-b',
      );
      await c.read(profileRegistryProvider.notifier).addProfile(a);
      await c.read(profileRegistryProvider.notifier).addProfile(b);
      await c.read(profileRegistryProvider.notifier).setActive(a.id);

      final Dio dioA = await c.read(subsonicDioClientProvider.future);
      expect(dioA.options.baseUrl, 'http://a.nd:4533');

      await c.read(profileRegistryProvider.notifier).setActive(b.id);
      final Dio dioB = await c.read(subsonicDioClientProvider.future);
      expect(dioB.options.baseUrl, 'http://b.nd:4533');
    });
  });
}
