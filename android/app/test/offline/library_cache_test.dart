import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/offline/library_cache.dart';
import 'package:heerr/offline/offline_paths.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/providers/settings.dart';

import '../support/cred_test_support.dart';

class _FakeStorage implements SecureStorage {
  _FakeStorage(this._data);
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

ProviderContainer _container(Directory tmp, Map<String, String> seed) {
  // A1: creds now come from the active profile, not legacy secure keys.
  // Derive an active-profile override from the seed (empty seed → no profile,
  // exercising the "no creds" path).
  final String? nUrl = seed['navidrome_base_url'];
  final String? nUser = seed['navidrome_username'];
  return ProviderContainer(
    overrides: <Override>[
      secureStorageProvider
          .overrideWith((Ref<SecureStorage> ref) => _FakeStorage(seed)),
      if (nUrl != null && nUser != null)
        activeProfileOverride(
          navidromeBaseUrl: nUrl,
          navidromeUsername: nUser,
          navidromePassword: seed['navidrome_password'] ?? 'p',
        ),
      applicationDocumentsDirectoryProvider
          .overrideWith((ApplicationDocumentsDirectoryRef ref) async => tmp),
    ],
  );
}

const Map<String, String> _kCredsA = <String, String>{
  'navidrome_base_url': 'http://a:4533',
  'navidrome_username': 'u',
  'navidrome_password': 'p',
};

const Map<String, String> _kCredsB = <String, String>{
  'navidrome_base_url': 'http://b:4533',
  'navidrome_username': 'u',
  'navidrome_password': 'p',
};

void main() {
  initPrefsMock();
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('heerr-cache-');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('LibraryCache store', () {
    test('write then read returns the same map', () async {
      final ProviderContainer c = _container(tmp, _kCredsA);
      addTearDown(c.dispose);

      final LibraryCache cache = await c.read(libraryCacheProvider.future);
      final SettingsValue settings = await c.read(settingsProvider.future);

      await cache.write(settings, 'albums', <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'al-1', 'name': 'X'},
        ],
      });

      final Map<String, dynamic>? out =
          await cache.read(settings, 'albums');
      expect(out, isNotNull);
      expect(out!['items'], isA<List<dynamic>>());
      expect((out['items'] as List<dynamic>).first, <String, dynamic>{
        'id': 'al-1',
        'name': 'X',
      });
    });

    test('missing file → null (cache miss, no throw)', () async {
      final ProviderContainer c = _container(tmp, _kCredsA);
      addTearDown(c.dispose);

      final LibraryCache cache = await c.read(libraryCacheProvider.future);
      final SettingsValue settings = await c.read(settingsProvider.future);
      expect(await cache.read(settings, 'nope'), isNull);
    });

    test('corrupt JSON on disk → null (no crash)', () async {
      final ProviderContainer c = _container(tmp, _kCredsA);
      addTearDown(c.dispose);

      final LibraryCache cache = await c.read(libraryCacheProvider.future);
      final SettingsValue settings = await c.read(settingsProvider.future);

      // Write a corrupt file directly.
      final OfflinePaths paths =
          await c.read(offlinePathsProvider.future);
      final File f = paths.libraryCacheFile(settings, 'broken')!;
      await f.parent.create(recursive: true);
      await f.writeAsString('{not-json');

      expect(await cache.read(settings, 'broken'), isNull);
    });

    test('per-server scoping isolates two server-keys with the same key',
        () async {
      // Server A writes "albums".
      final ProviderContainer ca = _container(tmp, _kCredsA);
      addTearDown(ca.dispose);
      final LibraryCache cacheA =
          await ca.read(libraryCacheProvider.future);
      final SettingsValue sA = await ca.read(settingsProvider.future);
      await cacheA.write(sA, 'albums', <String, dynamic>{'origin': 'A'});

      // Server B writes "albums" with different content.
      final ProviderContainer cb = _container(tmp, _kCredsB);
      addTearDown(cb.dispose);
      final LibraryCache cacheB =
          await cb.read(libraryCacheProvider.future);
      final SettingsValue sB = await cb.read(settingsProvider.future);
      await cacheB.write(sB, 'albums', <String, dynamic>{'origin': 'B'});

      // Each server reads its own data; no cross-contamination.
      expect((await cacheA.read(sA, 'albums'))!['origin'], 'A');
      expect((await cacheB.read(sB, 'albums'))!['origin'], 'B');
    });

    test('write is atomic — tmp file does not linger', () async {
      final ProviderContainer c = _container(tmp, _kCredsA);
      addTearDown(c.dispose);

      final LibraryCache cache = await c.read(libraryCacheProvider.future);
      final SettingsValue settings = await c.read(settingsProvider.future);

      await cache.write(settings, 'k', <String, dynamic>{'a': 1});

      final OfflinePaths paths =
          await c.read(offlinePathsProvider.future);
      final Directory dir = paths.libraryCacheDir(settings)!;
      final List<String> names = await dir
          .list()
          .map((FileSystemEntity e) => e.path.split('/').last)
          .toList();
      expect(names, contains('k.json'));
      expect(names.where((String n) => n.endsWith('.tmp')), isEmpty);
    });

    test('no creds → write and read are no-ops (write skipped, read null)',
        () async {
      // No Navidrome creds — `libraryCacheFile` returns null and writes /
      // reads gracefully short-circuit.
      final ProviderContainer c = _container(tmp, <String, String>{});
      addTearDown(c.dispose);

      final LibraryCache cache = await c.read(libraryCacheProvider.future);
      final SettingsValue settings = await c.read(settingsProvider.future);

      // Should not throw.
      await cache.write(settings, 'k', <String, dynamic>{'a': 1});
      expect(await cache.read(settings, 'k'), isNull);
    });
  });

  group('cacheAware wrapper', () {
    test('network success writes cache + returns value', () async {
      final ProviderContainer c = _container(tmp, _kCredsA);
      addTearDown(c.dispose);

      int calls = 0;
      final FutureProvider<_Sample> p = FutureProvider<_Sample>(
        (Ref<AsyncValue<_Sample>> ref) async => cacheAware<_Sample>(
          ref: ref,
          cacheKey: 'sample',
          networkCall: () async {
            calls += 1;
            return const _Sample(id: 'sm-1', n: 7);
          },
          encode: (_Sample s) => s.toJson(),
          decode: (Map<String, dynamic> json) => _Sample.fromJson(json),
        ),
      );

      final _Sample value = await c.read(p.future);
      expect(calls, 1);
      expect(value, const _Sample(id: 'sm-1', n: 7));

      final LibraryCache cache = await c.read(libraryCacheProvider.future);
      final SettingsValue settings = await c.read(settingsProvider.future);
      final Map<String, dynamic>? cached =
          await cache.read(settings, 'sample');
      expect(cached, isNotNull);
      expect(cached!['id'], 'sm-1');
      expect(cached['n'], 7);
    });

    test('network failure + cached → returns cached value', () async {
      final ProviderContainer c = _container(tmp, _kCredsA);
      addTearDown(c.dispose);

      final LibraryCache cache = await c.read(libraryCacheProvider.future);
      final SettingsValue settings = await c.read(settingsProvider.future);
      await cache.write(
        settings,
        'sample',
        const _Sample(id: 'cached', n: 99).toJson(),
      );

      final FutureProvider<_Sample> p = FutureProvider<_Sample>(
        (Ref<AsyncValue<_Sample>> ref) async => cacheAware<_Sample>(
          ref: ref,
          cacheKey: 'sample',
          networkCall: () async => throw StateError('boom'),
          encode: (_Sample s) => s.toJson(),
          decode: (Map<String, dynamic> json) => _Sample.fromJson(json),
        ),
      );

      final _Sample v = await c.read(p.future);
      expect(v, const _Sample(id: 'cached', n: 99));
    });

    test('network failure + no cache → rethrows original error', () async {
      final ProviderContainer c = _container(tmp, _kCredsA);
      addTearDown(c.dispose);

      final FutureProvider<_Sample> p = FutureProvider<_Sample>(
        (Ref<AsyncValue<_Sample>> ref) async => cacheAware<_Sample>(
          ref: ref,
          cacheKey: 'sample',
          networkCall: () async => throw const FormatException('nope'),
          encode: (_Sample s) => s.toJson(),
          decode: (Map<String, dynamic> json) => _Sample.fromJson(json),
        ),
      );

      await expectLater(c.read(p.future), throwsA(isA<FormatException>()));
    });

    test(
        'offline (OnlineCheck=false) + cache hit → returns cached, never calls network',
        () async {
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          secureStorageProvider.overrideWith(
            (Ref<SecureStorage> ref) => _FakeStorage(_kCredsA),
          ),
          activeProfileOverride(
            navidromeBaseUrl: 'http://a:4533',
            navidromeUsername: 'u',
          ),
          applicationDocumentsDirectoryProvider
              .overrideWith((ApplicationDocumentsDirectoryRef ref) async => tmp),
          onlineCheckProvider
              .overrideWith((OnlineCheckRef ref) => _StubOnlineCheck(false)),
        ],
      );
      addTearDown(c.dispose);

      // Seed the cache as if a prior online browse populated it.
      final LibraryCache cache = await c.read(libraryCacheProvider.future);
      final SettingsValue settings = await c.read(settingsProvider.future);
      await cache.write(
        settings,
        'sample',
        const _Sample(id: 'cached', n: 99).toJson(),
      );

      int networkCalls = 0;
      final FutureProvider<_Sample> p = FutureProvider<_Sample>(
        (Ref<AsyncValue<_Sample>> ref) async => cacheAware<_Sample>(
          ref: ref,
          cacheKey: 'sample',
          networkCall: () async {
            networkCalls += 1;
            throw StateError('networkCall must not run when offline + cached');
          },
          encode: (_Sample s) => s.toJson(),
          decode: (Map<String, dynamic> json) => _Sample.fromJson(json),
        ),
      );

      final _Sample v = await c.read(p.future);
      expect(v, const _Sample(id: 'cached', n: 99));
      expect(networkCalls, 0);
    });

    test(
        'offline (OnlineCheck=false) + no cache → throws fast without calling network',
        () async {
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          secureStorageProvider.overrideWith(
            (Ref<SecureStorage> ref) => _FakeStorage(_kCredsA),
          ),
          activeProfileOverride(
            navidromeBaseUrl: 'http://a:4533',
            navidromeUsername: 'u',
          ),
          applicationDocumentsDirectoryProvider
              .overrideWith((ApplicationDocumentsDirectoryRef ref) async => tmp),
          onlineCheckProvider
              .overrideWith((OnlineCheckRef ref) => _StubOnlineCheck(false)),
        ],
      );
      addTearDown(c.dispose);

      int networkCalls = 0;
      final FutureProvider<_Sample> p = FutureProvider<_Sample>(
        (Ref<AsyncValue<_Sample>> ref) async => cacheAware<_Sample>(
          ref: ref,
          cacheKey: 'sample',
          networkCall: () async {
            networkCalls += 1;
            throw StateError('networkCall must not run when offline + no cache');
          },
          encode: (_Sample s) => s.toJson(),
          decode: (Map<String, dynamic> json) => _Sample.fromJson(json),
        ),
      );

      await expectLater(c.read(p.future), throwsA(anything));
      expect(networkCalls, 0);
    });

    test('online (OnlineCheck=true) → calls network and writes cache',
        () async {
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          secureStorageProvider.overrideWith(
            (Ref<SecureStorage> ref) => _FakeStorage(_kCredsA),
          ),
          activeProfileOverride(
            navidromeBaseUrl: 'http://a:4533',
            navidromeUsername: 'u',
          ),
          applicationDocumentsDirectoryProvider
              .overrideWith((ApplicationDocumentsDirectoryRef ref) async => tmp),
          onlineCheckProvider
              .overrideWith((OnlineCheckRef ref) => _StubOnlineCheck(true)),
        ],
      );
      addTearDown(c.dispose);

      int networkCalls = 0;
      final FutureProvider<_Sample> p = FutureProvider<_Sample>(
        (Ref<AsyncValue<_Sample>> ref) async => cacheAware<_Sample>(
          ref: ref,
          cacheKey: 'sample',
          networkCall: () async {
            networkCalls += 1;
            return const _Sample(id: 'live', n: 42);
          },
          encode: (_Sample s) => s.toJson(),
          decode: (Map<String, dynamic> json) => _Sample.fromJson(json),
        ),
      );

      final _Sample v = await c.read(p.future);
      expect(v, const _Sample(id: 'live', n: 42));
      expect(networkCalls, 1);

      // Cache was written by the wrapper.
      final LibraryCache cache = await c.read(libraryCacheProvider.future);
      final SettingsValue settings = await c.read(settingsProvider.future);
      final Map<String, dynamic>? cached =
          await cache.read(settings, 'sample');
      expect(cached, isNotNull);
      expect(cached!['id'], 'live');
    });

    test('infra unavailable bypass: still returns network value', () async {
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          secureStorageProvider.overrideWith(
            (Ref<SecureStorage> ref) => _FakeStorage(_kCredsA),
          ),
          libraryCacheProvider.overrideWith(
            (LibraryCacheRef ref) =>
                Future<LibraryCache>.error(StateError('no infra')),
          ),
        ],
      );
      addTearDown(c.dispose);

      final FutureProvider<_Sample> p = FutureProvider<_Sample>(
        (Ref<AsyncValue<_Sample>> ref) async => cacheAware<_Sample>(
          ref: ref,
          cacheKey: 'sample',
          networkCall: () async => const _Sample(id: 'live', n: 1),
          encode: (_Sample s) => s.toJson(),
          decode: (Map<String, dynamic> json) => _Sample.fromJson(json),
        ),
      );

      final _Sample v = await c.read(p.future);
      expect(v.id, 'live');
    });
  });
}

class _StubOnlineCheck implements OnlineCheck {
  _StubOnlineCheck(this._online);
  final bool _online;
  @override
  Future<bool> isLikelyOnline() async => _online;
}

class _Sample {
  const _Sample({required this.id, required this.n});
  final String id;
  final int n;

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'n': n};
  static _Sample fromJson(Map<String, dynamic> j) =>
      _Sample(id: j['id'] as String, n: j['n'] as int);

  @override
  bool operator ==(Object other) =>
      other is _Sample && other.id == id && other.n == n;
  @override
  int get hashCode => Object.hash(id, n);
}
