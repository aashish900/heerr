import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/offline/offline_manifest.dart';
import 'package:heerr/offline/offline_marker.dart';
import 'package:heerr/offline/offline_paths.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/providers/settings.dart';

import '../support/cred_test_support.dart';

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

Future<({ProviderContainer container, Directory tmp})> _makeEnv() async {
  final Directory tmp = await Directory.systemTemp.createTemp('heerr-marker-');
  final _FakeSecureStorage fake = _FakeSecureStorage(<String, String>{
    'navidrome_base_url': 'http://navi:4533',
    'navidrome_username': 'me',
    'navidrome_password': 'pw',
  });
  final ProviderContainer c = ProviderContainer(
    overrides: <Override>[
      secureStorageProvider.overrideWith((Ref<SecureStorage> ref) => fake),
      activeProfileOverride(),
      applicationDocumentsDirectoryProvider
          .overrideWith((ApplicationDocumentsDirectoryRef ref) async => tmp),
    ],
  );
  return (container: c, tmp: tmp);
}

void main() {
  initPrefsMock();
  group('OfflineMarker', () {
    test('markAlbum adds id to manifest.markedAlbums', () async {
      final ({ProviderContainer container, Directory tmp}) env =
          await _makeEnv();
      addTearDown(() async {
        env.container.dispose();
        if (await env.tmp.exists()) await env.tmp.delete(recursive: true);
      });

      await env.container.read(offlineMarkerProvider.future);
      await env.container
          .read(offlineMarkerProvider.notifier)
          .markAlbum('al-1');

      final OfflineManifest m =
          await env.container.read(offlineManifestProvider.future);
      expect(m.markedAlbums, <String>{'al-1'});
    });

    test('unmarkAlbum removes id', () async {
      final ({ProviderContainer container, Directory tmp}) env =
          await _makeEnv();
      addTearDown(() async {
        env.container.dispose();
        if (await env.tmp.exists()) await env.tmp.delete(recursive: true);
      });

      await env.container.read(offlineMarkerProvider.future);
      final OfflineMarker notifier =
          env.container.read(offlineMarkerProvider.notifier);
      await notifier.markAlbum('al-1');
      await notifier.markAlbum('al-2');
      await notifier.unmarkAlbum('al-1');

      final OfflineManifest m =
          await env.container.read(offlineManifestProvider.future);
      expect(m.markedAlbums, <String>{'al-2'});
    });

    test('mark/unmark/mark cycle is idempotent', () async {
      final ({ProviderContainer container, Directory tmp}) env =
          await _makeEnv();
      addTearDown(() async {
        env.container.dispose();
        if (await env.tmp.exists()) await env.tmp.delete(recursive: true);
      });

      await env.container.read(offlineMarkerProvider.future);
      final OfflineMarker n =
          env.container.read(offlineMarkerProvider.notifier);
      await n.markAlbum('al-1');
      await n.unmarkAlbum('al-1');
      await n.markAlbum('al-1');

      final OfflineManifest m =
          await env.container.read(offlineManifestProvider.future);
      expect(m.markedAlbums, <String>{'al-1'});
    });

    test('markPlaylist + unmarkPlaylist independent of albums', () async {
      final ({ProviderContainer container, Directory tmp}) env =
          await _makeEnv();
      addTearDown(() async {
        env.container.dispose();
        if (await env.tmp.exists()) await env.tmp.delete(recursive: true);
      });

      await env.container.read(offlineMarkerProvider.future);
      final OfflineMarker n =
          env.container.read(offlineMarkerProvider.notifier);
      await n.markAlbum('al-1');
      await n.markPlaylist('pl-1');
      await n.unmarkAlbum('al-1');

      final OfflineManifest m =
          await env.container.read(offlineManifestProvider.future);
      expect(m.markedAlbums, isEmpty);
      expect(m.markedPlaylists, <String>{'pl-1'});
    });

    test('marker change clears cached size estimate', () async {
      final ({ProviderContainer container, Directory tmp}) env =
          await _makeEnv();
      addTearDown(() async {
        env.container.dispose();
        if (await env.tmp.exists()) await env.tmp.delete(recursive: true);
      });

      // Pre-seed a manifest with a cached estimate via the store.
      await env.container.read(offlineMarkerProvider.future);
      final OfflineManifestStore store = await env.container
          .read(offlineManifestStoreProvider.future);
      final SettingsValue settings =
          await env.container.read(settingsProvider.future);
      await store.save(
        settings,
        OfflineManifest(
          markedAlbums: const <String>{'al-1'},
          estimatedTotalBytes: 1_000_000,
          estimatedAt: DateTime.now(),
        ),
      );
      env.container.invalidate(offlineManifestProvider);
      final OfflineManifest before =
          await env.container.read(offlineManifestProvider.future);
      expect(before.estimatedTotalBytes, 1_000_000);

      await env.container
          .read(offlineMarkerProvider.notifier)
          .markAlbum('al-2');

      final OfflineManifest after =
          await env.container.read(offlineManifestProvider.future);
      expect(after.estimatedTotalBytes, isNull);
      expect(after.estimatedAt, isNull);
    });
  });
}
