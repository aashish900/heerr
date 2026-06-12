import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/offline/local_uri.dart';
import 'package:heerr/offline/offline_manifest.dart';
import 'package:heerr/offline/offline_settings.dart';

OfflineSettingsValue _offlineSettings({
  bool enabled = true,
  bool syncAll = false,
  bool wifiOnly = true,
  int pollIntervalMinutes = 15,
}) =>
    (
      enabled: enabled,
      syncAll: syncAll,
      wifiOnly: wifiOnly,
      pollIntervalMinutes: pollIntervalMinutes,
    );

ProviderContainer _container({
  required OfflineSettingsValue settings,
  required OfflineManifest manifest,
}) {
  return ProviderContainer(
    overrides: <Override>[
      offlineSettingsProvider.overrideWith(
        () => _StubOfflineSettings(settings),
      ),
      offlineManifestProvider.overrideWith(
        (OfflineManifestRef ref) async => manifest,
      ),
    ],
  );
}

class _StubOfflineSettings extends OfflineSettings {
  _StubOfflineSettings(this._value);
  final OfflineSettingsValue _value;
  @override
  Future<OfflineSettingsValue> build() async => _value;
}

void main() {
  group('localUriForProvider', () {
    test('returns null when offline master switch is OFF', () async {
      final ProviderContainer c = _container(
        settings: _offlineSettings(enabled: false),
        manifest: const OfflineManifest(
          songs: <String, OfflineSongEntry>{
            'so-1': OfflineSongEntry(
              state: OfflineSongState.ready,
              localPath: '/tmp/so-1.mp3',
            ),
          },
        ),
      );
      addTearDown(c.dispose);

      // The provider depends on async ones; prime them.
      await c.read(offlineSettingsProvider.future);
      await c.read(offlineManifestProvider.future);

      expect(await c.read(localUriForProvider('so-1').future), isNull);
    });

    test('returns null when no manifest entry for songId', () async {
      final ProviderContainer c = _container(
        settings: _offlineSettings(),
        manifest: const OfflineManifest(),
      );
      addTearDown(c.dispose);
      await c.read(offlineSettingsProvider.future);
      await c.read(offlineManifestProvider.future);
      expect(await c.read(localUriForProvider('so-1').future), isNull);
    });

    test('returns null when entry state is queued / downloading / failed',
        () async {
      for (final OfflineSongState state in <OfflineSongState>[
        OfflineSongState.queued,
        OfflineSongState.downloading,
        OfflineSongState.failed,
      ]) {
        final ProviderContainer c = _container(
          settings: _offlineSettings(),
          manifest: OfflineManifest(
            songs: <String, OfflineSongEntry>{
              'so-1': OfflineSongEntry(
                state: state,
                localPath: '/tmp/so-1.mp3',
              ),
            },
          ),
        );
        addTearDown(c.dispose);
        await c.read(offlineSettingsProvider.future);
        await c.read(offlineManifestProvider.future);
        expect(
          await c.read(localUriForProvider('so-1').future),
          isNull,
          reason: 'state=$state should be stream-only',
        );
      }
    });

    test('returns file:// URI when entry is ready with a localPath', () async {
      final ProviderContainer c = _container(
        settings: _offlineSettings(),
        manifest: const OfflineManifest(
          songs: <String, OfflineSongEntry>{
            'so-1': OfflineSongEntry(
              state: OfflineSongState.ready,
              localPath: '/data/user/0/heerr/files/offline/x/songs/so-1.mp3',
            ),
          },
        ),
      );
      addTearDown(c.dispose);
      await c.read(offlineSettingsProvider.future);
      await c.read(offlineManifestProvider.future);

      final String? uri = await c.read(localUriForProvider('so-1').future);
      expect(uri, isNotNull);
      expect(uri, startsWith('file:///'));
      expect(uri, endsWith('/songs/so-1.mp3'));
    });

    test('returns null when ready entry has no localPath (defensive)',
        () async {
      final ProviderContainer c = _container(
        settings: _offlineSettings(),
        manifest: const OfflineManifest(
          songs: <String, OfflineSongEntry>{
            'so-1': OfflineSongEntry(state: OfflineSongState.ready),
          },
        ),
      );
      addTearDown(c.dispose);
      await c.read(offlineSettingsProvider.future);
      await c.read(offlineManifestProvider.future);
      expect(await c.read(localUriForProvider('so-1').future), isNull);
    });
  });
}
