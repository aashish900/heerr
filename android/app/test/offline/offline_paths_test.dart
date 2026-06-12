import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/offline/offline_paths.dart';
import 'package:heerr/providers/settings.dart';

SettingsValue _settings({
  String? url,
  String? user,
  String? pass,
}) {
  return (
    backendBaseUrl: null,
    bearerToken: null,
    navidromeBaseUrl: url,
    navidromeUsername: user,
    navidromePassword: pass,
    offlineEnabled: false,
    offlineSyncAll: false,
    offlineWifiOnly: true,
    offlinePollIntervalMin: 15,
  );
}

void main() {
  group('OfflinePaths.serverKey', () {
    test('deterministic for fixed creds', () {
      final String a = OfflinePaths.serverKey(
        navidromeBaseUrl: 'http://navi:4533',
        navidromeUsername: 'me',
      );
      final String b = OfflinePaths.serverKey(
        navidromeBaseUrl: 'http://navi:4533',
        navidromeUsername: 'me',
      );
      expect(a, b);
    });

    test('differs across distinct URLs', () {
      final String a = OfflinePaths.serverKey(
        navidromeBaseUrl: 'http://navi-a:4533',
        navidromeUsername: 'me',
      );
      final String b = OfflinePaths.serverKey(
        navidromeBaseUrl: 'http://navi-b:4533',
        navidromeUsername: 'me',
      );
      expect(a, isNot(b));
    });

    test('differs across distinct usernames at the same URL', () {
      final String a = OfflinePaths.serverKey(
        navidromeBaseUrl: 'http://navi:4533',
        navidromeUsername: 'me',
      );
      final String b = OfflinePaths.serverKey(
        navidromeBaseUrl: 'http://navi:4533',
        navidromeUsername: 'you',
      );
      expect(a, isNot(b));
    });

    test('is exactly 16 hex chars', () {
      final String k = OfflinePaths.serverKey(
        navidromeBaseUrl: 'http://navi:4533',
        navidromeUsername: 'me',
      );
      expect(k.length, 16);
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(k), isTrue);
    });
  });

  group('OfflinePaths.serverRoot / manifestFile / songFile', () {
    late Directory docsRoot;

    setUp(() async {
      docsRoot = await Directory.systemTemp.createTemp('heerr-offline-paths-');
    });

    tearDown(() async {
      if (await docsRoot.exists()) {
        await docsRoot.delete(recursive: true);
      }
    });

    test('returns null when Navidrome creds are missing', () {
      final OfflinePaths paths = OfflinePaths(docsRoot);
      final SettingsValue s = _settings();
      expect(paths.serverRoot(s), isNull);
      expect(paths.manifestFile(s), isNull);
      expect(paths.songFile(s, 'so-1', 'mp3'), isNull);
    });

    test('serverRoot lands under <docs>/offline/<server-key>', () {
      final OfflinePaths paths = OfflinePaths(docsRoot);
      final SettingsValue s = _settings(
        url: 'http://navi:4533',
        user: 'me',
        pass: 'pw',
      );
      final String key = OfflinePaths.serverKey(
        navidromeBaseUrl: 'http://navi:4533',
        navidromeUsername: 'me',
      );

      final Directory? root = paths.serverRoot(s);
      expect(root, isNotNull);
      expect(root!.path, '${docsRoot.path}/offline/$key');
    });

    test('manifestFile is <serverRoot>/manifest.json', () {
      final OfflinePaths paths = OfflinePaths(docsRoot);
      final SettingsValue s = _settings(
        url: 'http://navi:4533',
        user: 'me',
        pass: 'pw',
      );

      final File? manifest = paths.manifestFile(s);
      expect(manifest, isNotNull);
      expect(manifest!.path, endsWith('/manifest.json'));
      expect(manifest.path, startsWith(paths.serverRoot(s)!.path));
    });

    test('songFile is <serverRoot>/songs/<id>.<suffix>', () {
      final OfflinePaths paths = OfflinePaths(docsRoot);
      final SettingsValue s = _settings(
        url: 'http://navi:4533',
        user: 'me',
        pass: 'pw',
      );

      final File? song = paths.songFile(s, 'so-1', 'mp3');
      expect(song, isNotNull);
      expect(song!.path, '${paths.serverRoot(s)!.path}/songs/so-1.mp3');
    });

    test('songFile strips a leading dot from the suffix', () {
      final OfflinePaths paths = OfflinePaths(docsRoot);
      final SettingsValue s = _settings(
        url: 'http://navi:4533',
        user: 'me',
        pass: 'pw',
      );

      final File? song = paths.songFile(s, 'so-1', '.flac');
      expect(song!.path, endsWith('/songs/so-1.flac'));
    });
  });

  group('applicationDocumentsDirectoryProvider override seam', () {
    test('test override replaces the production path_provider call',
        () async {
      final Directory tmp =
          await Directory.systemTemp.createTemp('heerr-offline-docs-');
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });

      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          applicationDocumentsDirectoryProvider
              .overrideWith((ApplicationDocumentsDirectoryRef ref) async => tmp),
        ],
      );
      addTearDown(c.dispose);

      final OfflinePaths paths =
          await c.read(offlinePathsProvider.future);
      expect(paths.offlineRoot.path, '${tmp.path}/offline');
    });
  });
}
