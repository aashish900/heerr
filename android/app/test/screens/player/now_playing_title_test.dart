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
import 'package:heerr/offline/offline_paths.dart';
import 'package:heerr/player/heerr_audio_handler.dart';
import 'package:heerr/player/player_provider.dart';
import 'package:heerr/providers/library/favourites.dart';
import 'package:heerr/providers/queue.dart';
import 'package:heerr/providers/server_creds.dart';
import 'package:heerr/screens/player/now_playing_screen.dart';
import 'package:heerr/services/lyrics_service.dart';
import 'package:heerr/theme.dart';
import 'package:heerr/utils/palette.dart';
import 'package:heerr/widgets/waveform_seek_bar.dart';

/// NOWPLAYING.md NP4 — title hierarchy + glass favourite button.
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

// Same fix as now_playing_add_to_playlist_test.dart / now_playing_hero_art_test.dart.
class _NullOfflinePaths extends OfflinePaths {
  _NullOfflinePaths() : super(Directory.systemTemp);

  @override
  Directory? serverRoot(ServerCreds settings) => null;
}

MediaItem _songItem() => const MediaItem(
      id: 'http://stream/song-1',
      title: 'Track A',
      artist: 'Artist A',
      extras: <String, dynamic>{'subsonicId': 'song-1'},
    );

Widget _wrap({required Set<String> favouriteIds}) {
  final MediaItem item = _songItem();
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
        (Ref<AsyncValue<PlayerSnapshot>> ref) => Stream<PlayerSnapshot>.value(
          PlayerSnapshot(item: item, state: PlaybackState(playing: true)),
        ),
      ),
      playerQueueProvider.overrideWith(
        (Ref<AsyncValue<List<MediaItem>>> ref) =>
            Stream<List<MediaItem>>.value(<MediaItem>[]),
      ),
      currentMediaItemProvider.overrideWith(
        (Ref<AsyncValue<MediaItem?>> ref) => Stream<MediaItem?>.value(item),
      ),
      queueProvider.overrideWith(_StubQueue.new),
      favouriteSongIdsProvider.overrideWith(
        (Ref<AsyncValue<Set<String>>> ref) async => favouriteIds,
      ),
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

  testWidgets('title renders headlineMedium bold, artist dimmed below it',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(favouriteIds: const <String>{}));
    await tester.pumpAndSettle();

    final Text title = tester.widget<Text>(find.text('Track A'));
    expect(title.style?.fontWeight, FontWeight.w800);

    final Text artist = tester.widget<Text>(find.text('Artist A'));
    expect(artist.style?.color, Colors.white70);
  });

  testWidgets('not favourited → outline heart, no colour override',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(favouriteIds: const <String>{}));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });

  testWidgets('favourited → filled magenta heart',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(favouriteIds: const <String>{'song-1'}));
    await tester.pumpAndSettle();

    final Icon icon = tester.widget<Icon>(find.byIcon(Icons.favorite));
    expect(icon.color, heerrMagenta);
  });
}
