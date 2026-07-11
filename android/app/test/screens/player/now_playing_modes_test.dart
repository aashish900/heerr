import 'dart:io';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:heerr/api/subsonic_client.dart';
import 'package:heerr/models/job_view.dart';
import 'package:heerr/models/queue_response.dart';
import 'package:heerr/offline/offline_paths.dart';
import 'package:heerr/player/heerr_audio_handler.dart';
import 'package:heerr/services/lyrics_service.dart';
import 'package:heerr/player/player_provider.dart';
import 'package:heerr/providers/queue.dart';
import 'package:heerr/screens/player/now_playing_screen.dart';
import 'package:heerr/utils/palette.dart';
import 'package:heerr/widgets/waveform_seek_bar.dart';

class _MockHandler extends Mock implements HeerrAudioHandler {}

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

class _StubQueue extends Queue {
  @override
  Future<QueueResponse> build() async {
    return const QueueResponse(active: <JobView>[], recent: <JobView>[]);
  }

  @override
  void pause() {}

  @override
  Future<void> resume() async {}
}

PlayerSnapshot _snap({
  AudioServiceRepeatMode repeat = AudioServiceRepeatMode.none,
  AudioServiceShuffleMode shuffle = AudioServiceShuffleMode.none,
}) {
  return PlayerSnapshot(
    item: const MediaItem(id: 'http://stream/1', title: 'T', artist: 'A'),
    state: PlaybackState(repeatMode: repeat, shuffleMode: shuffle),
  );
}

Widget _wrap(PlayerSnapshot snapshot, HeerrAudioHandler handler) {
  return ProviderScope(
    overrides: <Override>[
      audioHandlerProvider.overrideWithValue(handler),
      applicationDocumentsDirectoryProvider.overrideWith(
        (ApplicationDocumentsDirectoryRef ref) async =>
            Directory.systemTemp.createTempSync('heerr-modes-'),
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
            Stream<PlayerSnapshot>.value(snapshot),
      ),
      playerQueueProvider.overrideWith(
        (Ref<AsyncValue<List<MediaItem>>> ref) =>
            Stream<List<MediaItem>>.value(<MediaItem>[]),
      ),
      currentMediaItemProvider.overrideWith(
        (Ref<AsyncValue<MediaItem?>> ref) =>
            Stream<MediaItem?>.value(snapshot.item),
      ),
      queueProvider.overrideWith(_StubQueue.new),
    ],
    child: const MaterialApp(home: NowPlayingScreen()),
  );
}

// Shuffle/repeat render bundled SVG glyphs, not Material icons — find them
// by the asset path baked into the SvgPicture's loader.
Finder _svgAsset(String asset) => find.byWidgetPredicate(
      (Widget w) =>
          w is SvgPicture &&
          w.bytesLoader is SvgAssetLoader &&
          (w.bytesLoader as SvgAssetLoader).assetName == asset,
    );

void main() {
  late _MockHandler handler;

  setUpAll(() {
    registerFallbackValue(AudioServiceRepeatMode.none);
    registerFallbackValue(AudioServiceShuffleMode.none);
  });

  setUp(() {
    paletteExtractorOverride = (Uri? _) async => null;
    heroArtFloatEnabled = false;
    waveformSeekBarAnimateEnabled = false;
    handler = _MockHandler();
    when(() => handler.setRepeatMode(any())).thenAnswer((_) async {});
    when(() => handler.setShuffleMode(any())).thenAnswer((_) async {});
  });

  tearDown(() {
    paletteExtractorOverride = dominantColorFor;
    heroArtFloatEnabled = true;
    waveformSeekBarAnimateEnabled = true;
  });

  testWidgets('shuffle + repeat buttons render', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(_snap(), handler));
    await tester.pumpAndSettle();
    expect(_svgAsset('assets/icons/shuffle.svg'), findsOneWidget);
    expect(_svgAsset('assets/icons/repeat.svg'), findsOneWidget);
  });

  testWidgets('repeat-one state shows repeat_one icon',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(_snap(repeat: AudioServiceRepeatMode.one), handler),
    );
    await tester.pumpAndSettle();
    expect(_svgAsset('assets/icons/repeat_one.svg'), findsOneWidget);
    expect(_svgAsset('assets/icons/repeat.svg'), findsNothing);
  });

  testWidgets('tap repeat from none → setRepeatMode(all)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(_snap(), handler));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('now-playing-repeat')));
    await tester.tap(find.byKey(const Key('now-playing-repeat')));
    await tester.pumpAndSettle();
    verify(() => handler.setRepeatMode(AudioServiceRepeatMode.all)).called(1);
  });

  testWidgets('tap repeat from all → setRepeatMode(one)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(_snap(repeat: AudioServiceRepeatMode.all), handler),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('now-playing-repeat')));
    await tester.tap(find.byKey(const Key('now-playing-repeat')));
    await tester.pumpAndSettle();
    verify(() => handler.setRepeatMode(AudioServiceRepeatMode.one)).called(1);
  });

  testWidgets('tap repeat from one → setRepeatMode(none)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(_snap(repeat: AudioServiceRepeatMode.one), handler),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('now-playing-repeat')));
    await tester.tap(find.byKey(const Key('now-playing-repeat')));
    await tester.pumpAndSettle();
    verify(() => handler.setRepeatMode(AudioServiceRepeatMode.none)).called(1);
  });

  testWidgets('tap shuffle from off → setShuffleMode(all)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(_snap(), handler));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('now-playing-shuffle')));
    await tester.tap(find.byKey(const Key('now-playing-shuffle')));
    await tester.pumpAndSettle();
    verify(() => handler.setShuffleMode(AudioServiceShuffleMode.all)).called(1);
  });

  testWidgets('tap shuffle from on → setShuffleMode(none)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(_snap(shuffle: AudioServiceShuffleMode.all), handler),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('now-playing-shuffle')));
    await tester.tap(find.byKey(const Key('now-playing-shuffle')));
    await tester.pumpAndSettle();
    verify(() => handler.setShuffleMode(AudioServiceShuffleMode.none)).called(1);
  });
}
