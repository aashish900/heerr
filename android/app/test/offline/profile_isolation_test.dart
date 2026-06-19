import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/profile.dart';
import 'package:heerr/offline/offline_paths.dart';
import 'package:heerr/providers/profiles/profile_registry.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/providers/settings.dart';

import '../support/cred_test_support.dart';

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

Profile _profile(String suffix) {
  final DateTime t = DateTime.utc(2026, 6, 17, 10, 0, 0);
  return Profile(
    id: 'p-$suffix',
    displayName: 'user-$suffix',
    heerrBaseUrl: 'http://h.$suffix:8000',
    heerrBearerToken: 'tok-$suffix',
    navidromeBaseUrl: 'http://nd.$suffix:4533',
    navidromeUsername: 'user-$suffix',
    navidromePassword: 'pw-$suffix',
    createdAt: t,
    lastUsedAt: t,
  );
}

void main() {
  initPrefsMock();
  group('S8 — profile isolation invariants', () {
    test('serverKey differs between two profiles', () {
      final Profile a = _profile('a');
      final Profile b = _profile('b');
      final String keyA = OfflinePaths.serverKey(
        navidromeBaseUrl: a.navidromeBaseUrl,
        navidromeUsername: a.navidromeUsername,
      );
      final String keyB = OfflinePaths.serverKey(
        navidromeBaseUrl: b.navidromeBaseUrl,
        navidromeUsername: b.navidromeUsername,
      );
      expect(keyA, isNot(keyB));
      expect(keyA, hasLength(16));
    });

    test(
        'settingsProvider reflects active profile creds — switching '
        'active profile produces a new serverKey via the existing '
        'chokepoint', () async {
      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          secureStorageProvider
              .overrideWith((Ref<SecureStorage> ref) => fake),
        ],
      );
      addTearDown(c.dispose);

      final Profile a = _profile('a');
      final Profile b = _profile('b');
      await c.read(profileRegistryProvider.future);
      await c.read(profileRegistryProvider.notifier).addProfile(a);
      await c.read(profileRegistryProvider.notifier).addProfile(b);

      // No active profile yet — settings echo whatever legacy keys held
      // (nothing in this test).
      SettingsValue v = await c.read(settingsProvider.future);
      expect(v.navidromeBaseUrl, isNull);
      expect(v.navidromeUsername, isNull);

      // Activate alice → settings sees alice's URL + username.
      await c.read(profileRegistryProvider.notifier).setActive(a.id);
      v = await c.read(settingsProvider.future);
      expect(v.navidromeBaseUrl, a.navidromeBaseUrl);
      expect(v.navidromeUsername, a.navidromeUsername);

      final String keyA = OfflinePaths.serverKey(
        navidromeBaseUrl: v.navidromeBaseUrl!,
        navidromeUsername: v.navidromeUsername!,
      );

      // Switch to bob → settings rebuilds with bob's identity.
      await c.read(profileRegistryProvider.notifier).setActive(b.id);
      v = await c.read(settingsProvider.future);
      expect(v.navidromeBaseUrl, b.navidromeBaseUrl);
      expect(v.navidromeUsername, b.navidromeUsername);

      final String keyB = OfflinePaths.serverKey(
        navidromeBaseUrl: v.navidromeBaseUrl!,
        navidromeUsername: v.navidromeUsername!,
      );
      expect(keyA, isNot(keyB));
    });

    test(
        'OfflinePaths.serverRoot returns disjoint directories per profile',
        () async {
      final Directory tmp = Directory.systemTemp.createTempSync('s8-iso');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final _FakeSecureStorage fake = _FakeSecureStorage();
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          secureStorageProvider
              .overrideWith((Ref<SecureStorage> ref) => fake),
          applicationDocumentsDirectoryProvider.overrideWith(
            (ApplicationDocumentsDirectoryRef ref) async => tmp,
          ),
        ],
      );
      addTearDown(c.dispose);

      final Profile a = _profile('a');
      final Profile b = _profile('b');
      await c.read(profileRegistryProvider.future);
      await c.read(profileRegistryProvider.notifier).addProfile(a);
      await c.read(profileRegistryProvider.notifier).addProfile(b);
      await c.read(profileRegistryProvider.notifier).setActive(a.id);

      final OfflinePaths paths = await c.read(offlinePathsProvider.future);
      SettingsValue v = await c.read(settingsProvider.future);
      final Directory? rootA = paths.serverRoot(v);
      expect(rootA, isNotNull);

      // Create a placeholder file under alice's offline root.
      rootA!.createSync(recursive: true);
      final File aMarker = File('${rootA.path}/manifest.json')
        ..writeAsStringSync('{}');

      // Switch to bob.
      await c.read(profileRegistryProvider.notifier).setActive(b.id);
      v = await c.read(settingsProvider.future);
      final Directory? rootB = paths.serverRoot(v);
      expect(rootB, isNotNull);
      expect(rootB!.path, isNot(rootA.path));

      // bob's directory is fresh — no leftover from alice.
      expect(File('${rootB.path}/manifest.json').existsSync(), isFalse);

      // Switching back to alice → her file is still on disk.
      await c.read(profileRegistryProvider.notifier).setActive(a.id);
      v = await c.read(settingsProvider.future);
      final Directory? rootAAgain = paths.serverRoot(v);
      expect(rootAAgain!.path, rootA.path);
      expect(aMarker.existsSync(), isTrue);
    });
  });
}
