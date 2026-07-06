import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/profile.dart';
import 'package:heerr/models/profile_meta.dart';
import 'package:heerr/providers/prefs_storage.dart';
import 'package:heerr/providers/profiles/active_profile.dart';
import 'package:heerr/providers/profiles/profile_meta.dart';

class _FakePrefs implements PrefsStorage {
  final Map<String, String> store = <String, String>{};
  @override
  Future<String?> read(String key) async => store[key];
  @override
  Future<void> write(String key, String value) async => store[key] = value;
  @override
  Future<void> delete(String key) async => store.remove(key);
}

Profile _profile(String id) => Profile(
      id: id,
      displayName: 'user-$id',
      heerrBaseUrl: 'http://h',
      heerrBearerToken: 't',
      navidromeBaseUrl: 'http://n',
      navidromeUsername: 'u-$id',
      navidromePassword: 'p',
      createdAt: DateTime.utc(2026),
      lastUsedAt: DateTime.utc(2026),
    );

ProviderContainer _container(_FakePrefs prefs, {Profile? active}) {
  return ProviderContainer(overrides: <Override>[
    prefsStorageProvider.overrideWithValue(prefs),
    activeProfileProvider.overrideWithValue(active),
  ]);
}

void main() {
  test('no active profile → empty meta; save is a no-op', () async {
    final _FakePrefs prefs = _FakePrefs();
    final ProviderContainer c = _container(prefs);
    addTearDown(c.dispose);

    final ProfileMeta meta = await c.read(profileMetaNotifierProvider.future);
    expect(meta.nickname, isNull);
    expect(meta.bio, isNull);

    await c
        .read(profileMetaNotifierProvider.notifier)
        .save(nickname: 'Nick', bio: 'hello');
    expect(prefs.store, isEmpty);
  });

  test('save + reload round-trips nickname and bio', () async {
    final _FakePrefs prefs = _FakePrefs();
    final ProviderContainer c = _container(prefs, active: _profile('a'));
    addTearDown(c.dispose);

    await c
        .read(profileMetaNotifierProvider.notifier)
        .save(nickname: 'Nick', bio: 'about me');

    final ProviderContainer c2 = _container(prefs, active: _profile('a'));
    addTearDown(c2.dispose);
    final ProfileMeta meta = await c2.read(profileMetaNotifierProvider.future);
    expect(meta.nickname, 'Nick');
    expect(meta.bio, 'about me');
  });

  test('blank strings persist as null (all fields optional)', () async {
    final _FakePrefs prefs = _FakePrefs();
    final ProviderContainer c = _container(prefs, active: _profile('a'));
    addTearDown(c.dispose);

    await c
        .read(profileMetaNotifierProvider.notifier)
        .save(nickname: '   ', bio: '');

    final ProfileMeta meta = await c.read(profileMetaNotifierProvider.future);
    expect(meta.nickname, isNull);
    expect(meta.bio, isNull);
  });

  test('meta is keyed per profile id', () async {
    final _FakePrefs prefs = _FakePrefs();
    final ProviderContainer cA = _container(prefs, active: _profile('a'));
    addTearDown(cA.dispose);
    await cA.read(profileMetaNotifierProvider.notifier).save(nickname: 'A');

    final ProviderContainer cB = _container(prefs, active: _profile('b'));
    addTearDown(cB.dispose);
    final ProfileMeta metaB =
        await cB.read(profileMetaNotifierProvider.future);
    expect(metaB.nickname, isNull);
  });

  test('corrupt persisted JSON falls back to empty meta', () async {
    final _FakePrefs prefs = _FakePrefs();
    prefs.store['profile_meta_a'] = '{not json';
    final ProviderContainer c = _container(prefs, active: _profile('a'));
    addTearDown(c.dispose);

    final ProfileMeta meta = await c.read(profileMetaNotifierProvider.future);
    expect(meta.nickname, isNull);
    expect(meta.bio, isNull);
  });
}
