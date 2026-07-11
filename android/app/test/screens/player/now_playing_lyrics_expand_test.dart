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
import 'package:heerr/providers/queue.dart';
import 'package:heerr/screens/player/now_playing_screen.dart';
import 'package:heerr/utils/palette.dart';
import 'package:heerr/widgets/waveform_seek_bar.dart';

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

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responder);
  final FutureOr<ResponseBody> Function(RequestOptions options) responder;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(String body) => ResponseBody.fromString(
      body,
      200,
      headers: <String, List<String>>{
        'content-type': <String>['application/json'],
      },
    );

PlayerSnapshot _snap({
  MediaItem? item,
  Duration position = Duration.zero,
}) {
  return PlayerSnapshot(
    item: item,
    state: PlaybackState(updatePosition: position),
  );
}

MediaItem _item() {
  return const MediaItem(
    id: 'http://stream/1',
    title: 'Rocky Mountain High',
    artist: 'John Denver',
    duration: Duration(minutes: 4),
    extras: <String, dynamic>{'subsonicId': 'so-1'},
  );
}

Widget _wrap({
  required PlayerSnapshot snapshot,
  required _FakeAdapter adapter,
}) {
  return ProviderScope(
    overrides: <Override>[
      applicationDocumentsDirectoryProvider.overrideWith(
        (ApplicationDocumentsDirectoryRef ref) async =>
            Directory.systemTemp.createTempSync('heerr-lyrics-expand-'),
      ),
      subsonicDioClientProvider.overrideWith(
        (Ref<AsyncValue<Dio>> ref) async {
          final Dio dio = Dio(BaseOptions(baseUrl: 'http://navi.test'));
          dio.httpClientAdapter = adapter;
          return dio;
        },
      ),
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

const String _syncedBody = '''
{"subsonic-response":{"status":"ok","version":"1.16.1",
  "lyricsList":{"structuredLyrics":[
    {"synced":true,"line":[
      {"start":0,"value":"He was born in the summer"},
      {"start":5000,"value":"Coming home to a place"},
      {"start":10000,"value":"He left yesterday behind"}]}
  ]}}}''';

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

  testWidgets('lyrics render inside a card with an expand affordance',
      (WidgetTester tester) async {
    final _FakeAdapter adapter = _FakeAdapter((_) => _json(_syncedBody));
    await tester.pumpWidget(_wrap(
      snapshot: _snap(item: _item(), position: const Duration(seconds: 6)),
      adapter: adapter,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('now-playing-lyrics-card')), findsOneWidget);
    expect(find.byKey(const Key('now-playing-lyrics-expand')), findsOneWidget);
  });

  testWidgets(
      'tapping expand opens the full-screen lyrics sheet with the '
      'album-art corner thumbnail and collapse chevron closes it',
      (WidgetTester tester) async {
    final _FakeAdapter adapter = _FakeAdapter((_) => _json(_syncedBody));
    await tester.pumpWidget(_wrap(
      snapshot: _snap(item: _item(), position: const Duration(seconds: 6)),
      adapter: adapter,
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('now-playing-lyrics-expand')),
    );
    await tester.tap(find.byKey(const Key('now-playing-lyrics-expand')));
    await tester.pumpAndSettle();

    final Finder sheet = find.byKey(const Key('now-playing-lyrics-sheet'));
    expect(sheet, findsOneWidget);
    expect(find.byKey(const Key('lyrics-sheet-art')), findsOneWidget);
    // Lyrics rendered inside the sheet, in the big synced pane.
    expect(
      find.descendant(
        of: sheet,
        matching: find.text('Coming home to a place'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('lyrics-sheet-collapse')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('now-playing-lyrics-sheet')), findsNothing);
  });

  // NP7 — the action pill's Lyrics slot is a second entry point to the same
  // expanded sheet as the card's own expand icon.
  testWidgets('action pill Lyrics slot also opens the full-screen sheet',
      (WidgetTester tester) async {
    final _FakeAdapter adapter = _FakeAdapter((_) => _json(_syncedBody));
    await tester.pumpWidget(_wrap(
      snapshot: _snap(item: _item(), position: const Duration(seconds: 6)),
      adapter: adapter,
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('now-playing-pill-lyrics')),
    );
    await tester.tap(find.byKey(const Key('now-playing-pill-lyrics')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('now-playing-lyrics-sheet')), findsOneWidget);
  });
}
