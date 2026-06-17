import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/profile.dart';
import 'package:heerr/providers/profiles/legacy_migration.dart';
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

Map<String, String> _fullLegacyCreds() => <String, String>{
      kLegacyBackendBaseUrl: 'http://100.64.0.1:8000',
      kLegacyBearerToken: 'tok-legacy',
      kLegacyNavidromeBaseUrl: 'http://100.64.0.1:4533',
      kLegacyNavidromeUsername: 'alice',
      kLegacyNavidromePassword: 'hunter2',
    };

void main() {
  group('migrateLegacyCreds', () {
    final DateTime fixedNow = DateTime.utc(2026, 6, 17, 12, 0, 0);

    test('full legacy creds → migrates to a Profile + clears legacy keys',
        () async {
      final _FakeSecureStorage fake = _FakeSecureStorage(_fullLegacyCreds());
      final ProviderContainer c = _container(fake);
      addTearDown(c.dispose);

      final Profile? migrated = await migrateLegacyCreds(
        c,
        now: () => fixedNow,
        newId: () => 'fixed-id-001',
      );

      expect(migrated, isNotNull);
      expect(migrated!.id, 'fixed-id-001');
      expect(migrated.displayName, 'alice');
      expect(migrated.heerrBaseUrl, 'http://100.64.0.1:8000');
      expect(migrated.heerrBearerToken, 'tok-legacy');
      expect(migrated.navidromeBaseUrl, 'http://100.64.0.1:4533');
      expect(migrated.navidromeUsername, 'alice');
      expect(migrated.navidromePassword, 'hunter2');
      expect(migrated.createdAt, fixedNow);
      expect(migrated.lastUsedAt, fixedNow);

      // Registry now has the profile + active pointer.
      final ProfileRegistryState s =
          await c.read(profileRegistryProvider.future);
      expect(s.profiles.single, migrated);
      expect(s.activeId, 'fixed-id-001');

      // Legacy keys swept.
      final Map<String, String> snap = fake.snapshot;
      expect(snap.containsKey(kLegacyBackendBaseUrl), isFalse);
      expect(snap.containsKey(kLegacyBearerToken), isFalse);
      expect(snap.containsKey(kLegacyNavidromeBaseUrl), isFalse);
      expect(snap.containsKey(kLegacyNavidromeUsername), isFalse);
      expect(snap.containsKey(kLegacyNavidromePassword), isFalse);
      expect(snap[kActiveProfileIdKey], 'fixed-id-001');
      expect(snap[kProfilesIndexKey], isNotNull);
    });

    test('fresh install (no legacy keys) → no-op', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c = _container(fake);
      addTearDown(c.dispose);

      final Profile? migrated = await migrateLegacyCreds(
        c,
        now: () => fixedNow,
        newId: () => 'fixed-id-002',
      );

      expect(migrated, isNull);
      final ProfileRegistryState s =
          await c.read(profileRegistryProvider.future);
      expect(s.profiles, isEmpty);
      expect(s.activeId, isNull);
      expect(fake.snapshot.containsKey(kProfilesIndexKey), isFalse);
    });

    test('already-migrated state (profiles index exists) → no-op', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage(<String, String>{
        ..._fullLegacyCreds(),
        kProfilesIndexKey: '{"profiles":[]}',
      });
      final ProviderContainer c = _container(fake);
      addTearDown(c.dispose);

      final Profile? migrated = await migrateLegacyCreds(
        c,
        now: () => fixedNow,
        newId: () => 'fixed-id-003',
      );

      expect(migrated, isNull);
      // Legacy keys still present — guard didn't sweep them on a no-op.
      expect(fake.snapshot[kLegacyBackendBaseUrl], 'http://100.64.0.1:8000');
    });

    test('partial legacy creds (missing navidrome password) → no-op', () async {
      final Map<String, String> partial = _fullLegacyCreds()
        ..remove(kLegacyNavidromePassword);
      final _FakeSecureStorage fake = _FakeSecureStorage(partial);
      final ProviderContainer c = _container(fake);
      addTearDown(c.dispose);

      final Profile? migrated = await migrateLegacyCreds(
        c,
        now: () => fixedNow,
        newId: () => 'fixed-id-004',
      );

      expect(migrated, isNull);
      // Legacy keys are preserved so S5 can read them as defaults (or be
      // discarded once the user re-enters them). Migration deliberately
      // doesn't touch them on the partial path.
      expect(fake.snapshot[kLegacyBackendBaseUrl], 'http://100.64.0.1:8000');
      final ProfileRegistryState s =
          await c.read(profileRegistryProvider.future);
      expect(s.profiles, isEmpty);
    });

    test('idempotent — running migration twice leaves state unchanged',
        () async {
      final _FakeSecureStorage fake = _FakeSecureStorage(_fullLegacyCreds());
      final ProviderContainer c = _container(fake);
      addTearDown(c.dispose);

      final Profile? first = await migrateLegacyCreds(
        c,
        now: () => fixedNow,
        newId: () => 'fixed-id-005',
      );
      expect(first, isNotNull);
      final Map<String, String> afterFirst = fake.snapshot;

      // Second run after the legacy sweep — no legacy keys present, no
      // new profile written, returns null.
      final Profile? second = await migrateLegacyCreds(
        c,
        now: () => fixedNow,
        newId: () => 'fixed-id-006',
      );
      expect(second, isNull);
      expect(fake.snapshot, afterFirst);
    });

    test('empty navidrome username falls back to displayName "default"',
        () async {
      final Map<String, String> creds = _fullLegacyCreds()
        ..[kLegacyNavidromeUsername] = '';
      final _FakeSecureStorage fake = _FakeSecureStorage(creds);
      final ProviderContainer c = _container(fake);
      addTearDown(c.dispose);

      final Profile? migrated = await migrateLegacyCreds(
        c,
        now: () => fixedNow,
        newId: () => 'fixed-id-007',
      );
      expect(migrated, isNull,
          reason:
              'empty username should be treated as missing creds — the '
              'login flow requires a real username.');
    });
  });
}
