import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/subsonic_client.dart';
import 'package:heerr/models/job_view.dart';
import 'package:heerr/models/queue_response.dart';
import 'package:heerr/offline/offline_manifest.dart';
import 'package:heerr/offline/offline_marker.dart';
import 'package:heerr/offline/offline_paths.dart';
import 'package:heerr/player/heerr_audio_handler.dart';
import 'package:heerr/player/player_provider.dart';
import 'package:heerr/providers/queue.dart';
import 'package:heerr/providers/server_creds.dart';
import 'package:heerr/screens/player/now_playing_screen.dart';
import 'package:heerr/services/lyrics_service.dart';
import 'package:heerr/theme.dart';
import 'package:heerr/utils/palette.dart';
import 'package:heerr/widgets/waveform_seek_bar.dart';

/// NOWPLAYING.md NP3 — hero art glow/border + on-art download-state button
/// (§2.4: reflects the existing per-song manifest state; no per-song
/// download mutation exists, so the "not downloaded" case explains rather
/// than silently no-ops).
class _StubQueue extends Queue {
  @override
  Future<QueueResponse> build() async =>
      const QueueResponse(active: <JobView>[], recent: <JobView>[]);

  @override
  void pause() {}

  @override
  Future<void> resume() async {}
}

class _NoopAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"subsonic-response":{"status":"ok"}}',
      200,
      headers: <String, List<String>>{
        'content-type': <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

// Prevents file.exists() I/O inside LyricsCache.read when creds are
// non-null — without this, pumpAndSettle hangs forever on the lyrics
// section's loading spinner (real OS I/O never drains under fake-async).
// Same fix as now_playing_add_to_playlist_test.dart.
class _NullOfflinePaths extends OfflinePaths {
  _NullOfflinePaths() : super(Directory.systemTemp);

  @override
  Directory? serverRoot(ServerCreds settings) => null;
}

class _MockOfflineMarker extends OfflineMarker {
  final List<String> deletedSongIds = <String>[];

  @override
  Future<void> build() async {}

  @override
  Future<void> deleteSongLocally(String songId) async {
    deletedSongIds.add(songId);
  }
}

PlayerSnapshot _snap(MediaItem item) =>
    PlayerSnapshot(item: item, state: PlaybackState(playing: true));

MediaItem _songItem({String subsonicId = 'song-1'}) => MediaItem(
      id: 'http://stream/$subsonicId',
      title: 'Track A',
      artist: 'Artist A',
      extras: <String, dynamic>{'subsonicId': subsonicId},
    );

MediaItem _previewItem() => const MediaItem(
      id: 'https://music.youtube.com/watch?v=x',
      title: 'Preview Track',
      artist: 'Artist P',
      extras: <String, dynamic>{'preview': true},
    );

Widget _wrap({
  required MediaItem item,
  OfflineManifest manifest = const OfflineManifest(),
  _MockOfflineMarker? marker,
}) {
  return ProviderScope(
    overrides: <Override>[
      offlinePathsProvider.overrideWith(
        (OfflinePathsRef ref) async => _NullOfflinePaths(),
      ),
      subsonicDioClientProvider.overrideWith(
        (Ref<AsyncValue<Dio>> ref) async {
          final Dio dio = Dio(BaseOptions(baseUrl: 'http://navi.test'));
          dio.httpClientAdapter = _NoopAdapter();
          return dio;
        },
      ),
      lyricsServiceProvider.overrideWith((LyricsServiceRef ref) async {
        final Dio subsonic = await ref.watch(subsonicDioClientProvider.future);
        final Dio lrcLib = Dio(BaseOptions(baseUrl: 'http://navi.test'));
        lrcLib.httpClientAdapter = _NoopAdapter();
        return LyricsService(subsonic, lrcLibDio: lrcLib);
      }),
      playerSnapshotProvider.overrideWith(
        (Ref<AsyncValue<PlayerSnapshot>> ref) =>
            Stream<PlayerSnapshot>.value(_snap(item)),
      ),
      playerQueueProvider.overrideWith(
        (Ref<AsyncValue<List<MediaItem>>> ref) =>
            Stream<List<MediaItem>>.value(<MediaItem>[]),
      ),
      currentMediaItemProvider.overrideWith(
        (Ref<AsyncValue<MediaItem?>> ref) => Stream<MediaItem?>.value(item),
      ),
      queueProvider.overrideWith(_StubQueue.new),
      offlineManifestProvider.overrideWith(
        (OfflineManifestRef ref) async => manifest,
      ),
      if (marker != null) offlineMarkerProvider.overrideWith(() => marker),
      serverCredsProvider.overrideWith(
        (Ref<ServerCreds> ref) => (
          navidromeBaseUrl: 'http://navi.test',
          navidromeUsername: 'tester',
          navidromePassword: 'pw',
        ),
      ),
    ],
    child: const MaterialApp(home: NowPlayingScreen()),
  );
}

void main() {
  setUp(() {
    paletteExtractorOverride = (Uri? _) async => null;
    heroArtFloatEnabled = false;
    waveformSeekBarAnimateEnabled = false;
  });
  tearDown(() {
    paletteExtractorOverride = dominantColorFor;
    heroArtFloatEnabled = true;
    waveformSeekBarAnimateEnabled = true;
  });

  testWidgets('no manifest entry → outlined download icon; tap shows explainer',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(item: _songItem()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
    await tester.tap(find.byKey(const Key('now-playing-hero-download')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        "Download this song's album or playlist to make it "
        'available offline.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('ready entry → filled magenta icon; tap deletes the local copy',
      (WidgetTester tester) async {
    final _MockOfflineMarker marker = _MockOfflineMarker();
    await tester.pumpWidget(_wrap(
      item: _songItem(subsonicId: 'song-1'),
      manifest: const OfflineManifest(
        songs: <String, OfflineSongEntry>{
          'song-1': OfflineSongEntry(state: OfflineSongState.ready),
        },
      ),
      marker: marker,
    ));
    await tester.pumpAndSettle();

    final Icon icon = tester.widget<Icon>(find.byIcon(Icons.download_done));
    expect(icon.color, heerrMagenta);

    await tester.tap(find.byKey(const Key('now-playing-hero-download')));
    await tester.pumpAndSettle();
    expect(marker.deletedSongIds, <String>['song-1']);
    expect(find.text('Removed from downloads'), findsOneWidget);
  });

  testWidgets('downloading entry → progress spinner, no button',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      item: _songItem(subsonicId: 'song-1'),
      manifest: const OfflineManifest(
        songs: <String, OfflineSongEntry>{
          'song-1': OfflineSongEntry(state: OfflineSongState.downloading),
        },
      ),
    ));
    // Bounded pump, not pumpAndSettle — the indeterminate spinner never
    // settles (that's the point of it while genuinely downloading).
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('now-playing-hero-download')), findsNothing);
  });

  testWidgets('queued entry → disabled schedule glyph',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      item: _songItem(subsonicId: 'song-1'),
      manifest: const OfflineManifest(
        songs: <String, OfflineSongEntry>{
          'song-1': OfflineSongEntry(state: OfflineSongState.queued),
        },
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.schedule), findsOneWidget);
  });

  testWidgets('failed entry → red error glyph with the error tooltip',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      item: _songItem(subsonicId: 'song-1'),
      manifest: const OfflineManifest(
        songs: <String, OfflineSongEntry>{
          'song-1': OfflineSongEntry(
            state: OfflineSongState.failed,
            lastError: 'disk full',
          ),
        },
      ),
    ));
    await tester.pumpAndSettle();

    final Icon icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
    expect(icon.color, Colors.redAccent);
    expect(find.byTooltip('disk full'), findsOneWidget);

    await tester.tap(find.byKey(const Key('now-playing-hero-download')));
    await tester.pumpAndSettle();
    expect(find.text('disk full'), findsOneWidget);
  });

  testWidgets('preview item (no song) → no download button at all',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(item: _previewItem()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('now-playing-hero-download')), findsNothing);
    expect(find.byIcon(Icons.download_outlined), findsNothing);
  });

  testWidgets('hero art container has 28dp rounded corners',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(item: _songItem()));
    await tester.pumpAndSettle();

    final Iterable<Container> containers =
        tester.widgetList<Container>(find.byType(Container));
    final bool hasHeroRadius = containers.any((Container c) {
      final BoxDecoration? d = c.decoration as BoxDecoration?;
      final BorderRadius? r = d?.borderRadius as BorderRadius?;
      return r?.topLeft == const Radius.circular(28);
    });
    expect(hasHeroRadius, isTrue);
  });
}
