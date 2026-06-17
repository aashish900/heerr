import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/profile.dart';
import 'package:heerr/providers/profiles/profile_registry.dart';
import 'package:heerr/providers/secure_storage.dart';

class _FakeSecureStorage implements SecureStorage {
  _FakeSecureStorage([Map<String, String>? seed])
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

ProviderContainer _container(_FakeSecureStorage fake) {
  return ProviderContainer(
    overrides: <Override>[
      secureStorageProvider.overrideWith((Ref<SecureStorage> ref) => fake),
    ],
  );
}

Profile _profile({
  String id = 'p1',
  String displayName = 'alice',
  String navidromeUsername = 'alice',
  DateTime? createdAt,
  DateTime? lastUsedAt,
}) {
  final DateTime c = createdAt ?? DateTime.utc(2026, 6, 17, 9, 0, 0);
  return Profile(
    id: id,
    displayName: displayName,
    heerrBaseUrl: 'http://100.64.0.1:8000',
    heerrBearerToken: 'tok-$id',
    navidromeBaseUrl: 'http://100.64.0.1:4533',
    navidromeUsername: navidromeUsername,
    navidromePassword: 'pw-$id',
    createdAt: c,
    lastUsedAt: lastUsedAt ?? c,
  );
}

void main() {
  group('ProfileRegistry', () {
    test('fresh storage → empty profiles + null activeId', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c = _container(fake);
      addTearDown(c.dispose);

      final ProfileRegistryState s =
          await c.read(profileRegistryProvider.future);
      expect(s.profiles, isEmpty);
      expect(s.activeId, isNull);
    });

    test('addProfile persists and exposes the new profile', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c = _container(fake);
      addTearDown(c.dispose);

      // Materialise initial state.
      await c.read(profileRegistryProvider.future);
      final Profile p = _profile();
      await c.read(profileRegistryProvider.notifier).addProfile(p);

      final ProfileRegistryState s =
          await c.read(profileRegistryProvider.future);
      expect(s.profiles.single, p);

      // Read-after-write parity: bypass the provider, parse the raw blob.
      final String? raw = fake.snapshot[kProfilesIndexKey];
      expect(raw, isNotNull);
      final Map<String, dynamic> decoded =
          jsonDecode(raw!) as Map<String, dynamic>;
      final List<dynamic> list = decoded['profiles'] as List<dynamic>;
      expect(list, hasLength(1));
      expect(
        Profile.fromJson(list.first as Map<String, dynamic>),
        p,
      );
    });

    test('addProfile updates in place when id matches', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c = _container(fake);
      addTearDown(c.dispose);

      await c.read(profileRegistryProvider.future);
      final Profile p = _profile();
      await c.read(profileRegistryProvider.notifier).addProfile(p);
      final Profile renamed = p.copyWith(displayName: 'alice-laptop');
      await c.read(profileRegistryProvider.notifier).addProfile(renamed);

      final ProfileRegistryState s =
          await c.read(profileRegistryProvider.future);
      expect(s.profiles, <Profile>[renamed]);
    });

    test('setActive persists the active pointer', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c = _container(fake);
      addTearDown(c.dispose);

      await c.read(profileRegistryProvider.future);
      final Profile p = _profile();
      await c.read(profileRegistryProvider.notifier).addProfile(p);
      await c.read(profileRegistryProvider.notifier).setActive(p.id);

      final ProfileRegistryState s =
          await c.read(profileRegistryProvider.future);
      expect(s.activeId, p.id);
      expect(fake.snapshot[kActiveProfileIdKey], p.id);
    });

    test('setActive(null) clears the active pointer', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c = _container(fake);
      addTearDown(c.dispose);

      await c.read(profileRegistryProvider.future);
      final Profile p = _profile();
      await c.read(profileRegistryProvider.notifier).addProfile(p);
      await c.read(profileRegistryProvider.notifier).setActive(p.id);
      await c.read(profileRegistryProvider.notifier).setActive(null);

      final ProfileRegistryState s =
          await c.read(profileRegistryProvider.future);
      expect(s.activeId, isNull);
      expect(fake.snapshot.containsKey(kActiveProfileIdKey), isFalse);
    });

    test('setActive throws on unknown id', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c = _container(fake);
      addTearDown(c.dispose);

      await c.read(profileRegistryProvider.future);
      await expectLater(
        () => c.read(profileRegistryProvider.notifier).setActive('nope'),
        throwsStateError,
      );
    });

    test('removeProfile clears the active pointer when active was removed',
        () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c = _container(fake);
      addTearDown(c.dispose);

      await c.read(profileRegistryProvider.future);
      final Profile a = _profile(id: 'p-a', displayName: 'alice');
      final Profile b = _profile(id: 'p-b', displayName: 'bob');
      await c.read(profileRegistryProvider.notifier).addProfile(a);
      await c.read(profileRegistryProvider.notifier).addProfile(b);
      await c.read(profileRegistryProvider.notifier).setActive(a.id);
      await c.read(profileRegistryProvider.notifier).removeProfile(a.id);

      final ProfileRegistryState s =
          await c.read(profileRegistryProvider.future);
      expect(s.profiles, <Profile>[b]);
      expect(s.activeId, isNull);
      expect(fake.snapshot.containsKey(kActiveProfileIdKey), isFalse);
    });

    test('removeProfile leaves the active pointer alone when other removed',
        () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c = _container(fake);
      addTearDown(c.dispose);

      await c.read(profileRegistryProvider.future);
      final Profile a = _profile(id: 'p-a');
      final Profile b = _profile(id: 'p-b');
      await c.read(profileRegistryProvider.notifier).addProfile(a);
      await c.read(profileRegistryProvider.notifier).addProfile(b);
      await c.read(profileRegistryProvider.notifier).setActive(a.id);
      await c.read(profileRegistryProvider.notifier).removeProfile(b.id);

      final ProfileRegistryState s =
          await c.read(profileRegistryProvider.future);
      expect(s.profiles, <Profile>[a]);
      expect(s.activeId, a.id);
    });

    test('bumpLastUsed updates only the targeted profile', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c = _container(fake);
      addTearDown(c.dispose);

      await c.read(profileRegistryProvider.future);
      final Profile a = _profile(id: 'p-a');
      final Profile b = _profile(id: 'p-b');
      await c.read(profileRegistryProvider.notifier).addProfile(a);
      await c.read(profileRegistryProvider.notifier).addProfile(b);

      final DateTime later = DateTime.utc(2026, 6, 18, 11, 0, 0);
      await c
          .read(profileRegistryProvider.notifier)
          .bumpLastUsed(a.id, now: later);

      final ProfileRegistryState s =
          await c.read(profileRegistryProvider.future);
      final Profile updatedA =
          s.profiles.firstWhere((Profile p) => p.id == a.id);
      final Profile sameB = s.profiles.firstWhere((Profile p) => p.id == b.id);
      expect(updatedA.lastUsedAt, later);
      expect(updatedA.createdAt, a.createdAt);
      expect(sameB.lastUsedAt, b.lastUsedAt);
    });

    test('bumpLastUsed is a no-op for unknown id', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c = _container(fake);
      addTearDown(c.dispose);

      await c.read(profileRegistryProvider.future);
      final Profile a = _profile();
      await c.read(profileRegistryProvider.notifier).addProfile(a);
      final String beforeBlob = fake.snapshot[kProfilesIndexKey]!;

      await c
          .read(profileRegistryProvider.notifier)
          .bumpLastUsed('does-not-exist');

      expect(fake.snapshot[kProfilesIndexKey], beforeBlob);
    });

    test('persistence round-trip — second container reads same state',
        () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c1 = _container(fake);
      addTearDown(c1.dispose);

      await c1.read(profileRegistryProvider.future);
      final Profile p = _profile();
      await c1.read(profileRegistryProvider.notifier).addProfile(p);
      await c1.read(profileRegistryProvider.notifier).setActive(p.id);

      final ProviderContainer c2 = _container(fake);
      addTearDown(c2.dispose);
      final ProfileRegistryState s =
          await c2.read(profileRegistryProvider.future);
      expect(s.profiles, <Profile>[p]);
      expect(s.activeId, p.id);
    });

    test('corrupt index blob → empty registry', () async {
      final _FakeSecureStorage fake =
          _FakeSecureStorage(<String, String>{kProfilesIndexKey: 'not-json'});
      final ProviderContainer c = _container(fake);
      addTearDown(c.dispose);

      final ProfileRegistryState s =
          await c.read(profileRegistryProvider.future);
      expect(s.profiles, isEmpty);
    });

    test('dangling active pointer is dropped on load', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage(<String, String>{
        kActiveProfileIdKey: 'ghost-id',
      });
      final ProviderContainer c = _container(fake);
      addTearDown(c.dispose);

      final ProfileRegistryState s =
          await c.read(profileRegistryProvider.future);
      expect(s.activeId, isNull);
    });
  });
}
