import 'dart:async';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/subsonic_client.dart';
import 'package:heerr/models/job_view.dart';
import 'package:heerr/models/queue_response.dart';
import 'package:heerr/player/heerr_audio_handler.dart';
import 'package:heerr/player/player_provider.dart';
import 'package:heerr/providers/queue.dart';
import 'package:heerr/screens/player/now_playing_screen.dart';
import 'package:heerr/utils/palette.dart';

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
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    calls++;
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

PlayerSnapshot _snap({MediaItem? item, bool playing = false}) {
  return PlayerSnapshot(
    item: item,
    state: PlaybackState(playing: playing),
  );
}

MediaItem _item({
  String id = 'http://stream/1',
  String title = 'Let It Happen',
  String? artist = 'Tame Impala',
  String? subsonicId = 'so-1',
}) {
  final Map<String, dynamic>? extras = subsonicId == null
      ? null
      : <String, dynamic>{'subsonicId': subsonicId};
  return MediaItem(
    id: id,
    title: title,
    artist: artist,
    duration: const Duration(minutes: 3),
    extras: extras,
  );
}

Widget _wrap({
  required PlayerSnapshot snapshot,
  required _FakeAdapter adapter,
}) {
  return ProviderScope(
    overrides: <Override>[
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

const Key _toggleKey = Key('now-playing-lyrics-toggle');

void main() {
  setUp(() {
    paletteExtractorOverride = (Uri? _) async => null;
  });
  tearDown(() {
    paletteExtractorOverride = dominantColorFor;
  });

  testWidgets('toggle button is visible in the AppBar',
      (WidgetTester tester) async {
    final _FakeAdapter adapter = _FakeAdapter(
      (_) => _json('{"subsonic-response":{"status":"ok"}}'),
    );
    await tester.pumpWidget(_wrap(
      snapshot: _snap(item: _item()),
      adapter: adapter,
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(_toggleKey), findsOneWidget);
  });

  testWidgets('tap toggles cover ↔ lyrics; second tap reverts',
      (WidgetTester tester) async {
    final _FakeAdapter adapter = _FakeAdapter(
      (_) => _json('''
{"subsonic-response":{"status":"ok","version":"1.16.1",
  "lyricsList":{"structuredLyrics":[
    {"line":[{"value":"Lyric line one"},{"value":"Lyric line two"}]}
  ]}}}'''),
    );
    await tester.pumpWidget(_wrap(
      snapshot: _snap(item: _item()),
      adapter: adapter,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('now-playing-lyrics-scroll')), findsNothing);

    await tester.tap(find.byKey(_toggleKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('now-playing-lyrics-scroll')), findsOneWidget);
    expect(find.textContaining('Lyric line one'), findsOneWidget);

    await tester.tap(find.byKey(_toggleKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('now-playing-lyrics-scroll')), findsNothing);
  });

  testWidgets('Subsonic code 70 → "No lyrics for this track" empty state',
      (WidgetTester tester) async {
    final _FakeAdapter adapter = _FakeAdapter(
      (_) => _json('''
{"subsonic-response":{"status":"failed","version":"1.16.1",
  "error":{"code":70,"message":"no lyrics"}}}'''),
    );
    await tester.pumpWidget(_wrap(
      snapshot: _snap(item: _item()),
      adapter: adapter,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_toggleKey));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('now-playing-lyrics-empty')), findsOneWidget);
    expect(find.text('No lyrics for this track'), findsOneWidget);
  });

  testWidgets('other Subsonic error renders the error pane',
      (WidgetTester tester) async {
    final _FakeAdapter adapter = _FakeAdapter(
      (_) => _json('''
{"subsonic-response":{"status":"failed","version":"1.16.1",
  "error":{"code":40,"message":"wrong password"}}}'''),
    );
    await tester.pumpWidget(_wrap(
      snapshot: _snap(item: _item()),
      adapter: adapter,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_toggleKey));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('now-playing-lyrics-error')), findsOneWidget);
  });

  testWidgets('null subsonicId + empty artist/title → empty-state, no HTTP call',
      (WidgetTester tester) async {
    final _FakeAdapter adapter = _FakeAdapter(
      (_) => throw StateError('should not be called'),
    );
    // Provide an item with no subsonicId and no artist/title so both
    // stages short-circuit without hitting the network.
    await tester.pumpWidget(_wrap(
      snapshot: _snap(item: _item(subsonicId: null, artist: null, title: '')),
      adapter: adapter,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_toggleKey));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('now-playing-lyrics-empty')), findsOneWidget);
    expect(adapter.calls, 0);
  });
}
