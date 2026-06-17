import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/profile.dart';
import 'package:heerr/providers/profiles/active_profile.dart';
import 'package:heerr/providers/profiles/profile_registry.dart';
import 'package:heerr/providers/secure_storage.dart';

class _FakeSecureStorage implements SecureStorage {
  _FakeSecureStorage([Map<String, String>? seed])
      : _data = <String, String>{...?seed};
  final Map<String, String> _data;

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

ProviderContainer _container(_FakeSecureStorage fake) {
  return ProviderContainer(
    overrides: <Override>[
      secureStorageProvider.overrideWith((Ref<SecureStorage> ref) => fake),
    ],
  );
}

Profile _profile(String id, {String name = 'alice'}) {
  final DateTime t = DateTime.utc(2026, 6, 17, 10, 0, 0);
  return Profile(
    id: id,
    displayName: name,
    heerrBaseUrl: 'http://h:8000',
    heerrBearerToken: 'tok-$id',
    navidromeBaseUrl: 'http://n:4533',
    navidromeUsername: name,
    navidromePassword: 'pw-$id',
    createdAt: t,
    lastUsedAt: t,
  );
}

void main() {
  group('activeProfileProvider', () {
    test('null when no profile active', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c = _container(fake);
      addTearDown(c.dispose);
      await c.read(profileRegistryProvider.future);
      expect(c.read(activeProfileProvider), isNull);
    });

    test('returns active profile after setActive', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c = _container(fake);
      addTearDown(c.dispose);

      await c.read(profileRegistryProvider.future);
      final Profile a = _profile('p-a');
      await c.read(profileRegistryProvider.notifier).addProfile(a);
      await c.read(profileRegistryProvider.notifier).setActive(a.id);

      expect(c.read(activeProfileProvider), a);
    });

    test('switching active profile updates the provider', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c = _container(fake);
      addTearDown(c.dispose);

      await c.read(profileRegistryProvider.future);
      final Profile a = _profile('p-a', name: 'alice');
      final Profile b = _profile('p-b', name: 'bob');
      await c.read(profileRegistryProvider.notifier).addProfile(a);
      await c.read(profileRegistryProvider.notifier).addProfile(b);
      await c.read(profileRegistryProvider.notifier).setActive(a.id);
      expect(c.read(activeProfileProvider)?.id, a.id);

      await c.read(profileRegistryProvider.notifier).setActive(b.id);
      expect(c.read(activeProfileProvider)?.id, b.id);
    });

    test('null when active id points to a removed profile', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c = _container(fake);
      addTearDown(c.dispose);

      await c.read(profileRegistryProvider.future);
      final Profile a = _profile('p-a');
      await c.read(profileRegistryProvider.notifier).addProfile(a);
      await c.read(profileRegistryProvider.notifier).setActive(a.id);
      await c.read(profileRegistryProvider.notifier).removeProfile(a.id);

      expect(c.read(activeProfileProvider), isNull);
    });
  });
}
