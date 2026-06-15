import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/api/subsonic_client.dart';
import 'package:heerr/models/subsonic/lyrics.dart';
import 'package:heerr/providers/library/lyrics.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responder);

  final FutureOr<ResponseBody> Function(RequestOptions options) responder;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    requests.add(options);
    return responder(options);
  }

  @override
  void close({bool force = false}) {}

  RequestOptions? get last => requests.isEmpty ? null : requests.last;
  RequestOptions? get first => requests.isEmpty ? null : requests.first;
}

ResponseBody _json(String body) => ResponseBody.fromString(
      body,
      200,
      headers: <String, List<String>>{
        'content-type': <String>['application/json'],
      },
    );


ProviderContainer _container(_FakeAdapter subsonicAdapter) {
  return ProviderContainer(
    overrides: <Override>[
      subsonicDioClientProvider.overrideWith(
        (Ref<AsyncValue<Dio>> ref) async {
          final Dio dio = Dio(BaseOptions(baseUrl: 'http://navi.test'));
          dio.httpClientAdapter = subsonicAdapter;
          return dio;
        },
      ),
    ],
  );
}

void main() {
  group('lyricsForProvider — Navidrome stage', () {
    test('hits /rest/getLyricsBySongId.view and parses structuredLyrics',
        () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json('''
{"subsonic-response":{"status":"ok","version":"1.16.1",
  "lyricsList":{"structuredLyrics":[
    {"line":[{"value":"It's always the same"},
             {"value":"Never gonna change"}]}
  ]}}}'''),
      );
      final ProviderContainer c = _container(adapter);
      addTearDown(c.dispose);

      final Lyrics? result =
          await c.read(lyricsForProvider('so-1', 'Tame Impala', 'Let It Happen').future);

      expect(adapter.first!.path, '/rest/getLyricsBySongId.view');
      expect(adapter.first!.queryParameters['id'], 'so-1');
      expect(result, isNotNull);
      expect(result!.value, "It's always the same\nNever gonna change");
    });

    test('Subsonic code 70 falls through to LRCLib stage (no crash)',
        () async {
      // Navidrome returns code 70. LRCLib is not reachable in tests →
      // the provider should return null (not throw).
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json('''
{"subsonic-response":{"status":"failed","version":"1.16.1",
  "error":{"code":70,"message":"no lyrics"}}}'''),
      );
      final ProviderContainer c = _container(adapter);
      addTearDown(c.dispose);

      // LRCLib will time out / fail in unit tests (no real network).
      // The provider must return null, not throw.
      final Lyrics? result = await c
          .read(lyricsForProvider('so-1', 'Artist', 'Title').future)
          .timeout(const Duration(seconds: 15), onTimeout: () => null);
      expect(result, isNull);
    });

    test('empty structuredLyrics falls through to LRCLib stage', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json('''
{"subsonic-response":{"status":"ok","version":"1.16.1",
  "lyricsList":{"structuredLyrics":[]}}}'''),
      );
      final ProviderContainer c = _container(adapter);
      addTearDown(c.dispose);

      final Lyrics? result = await c
          .read(lyricsForProvider('so-1', 'Artist', 'Title').future)
          .timeout(const Duration(seconds: 15), onTimeout: () => null);
      expect(result, isNull);
    });

    test('missing lyricsList falls through to LRCLib stage', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json(
            '{"subsonic-response":{"status":"ok","version":"1.16.1"}}'),
      );
      final ProviderContainer c = _container(adapter);
      addTearDown(c.dispose);

      final Lyrics? result = await c
          .read(lyricsForProvider('so-1', 'Artist', 'Title').future)
          .timeout(const Duration(seconds: 15), onTimeout: () => null);
      expect(result, isNull);
    });

    test('empty songId skips Navidrome stage entirely', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => throw StateError('Navidrome should not be called'),
      );
      final ProviderContainer c = _container(adapter);
      addTearDown(c.dispose);

      // No Navidrome call + LRCLib unreachable in tests → null.
      final Lyrics? result = await c
          .read(lyricsForProvider('', 'Artist', 'Title').future)
          .timeout(const Duration(seconds: 15), onTimeout: () => null);
      expect(result, isNull);
      expect(adapter.requests, isEmpty);
    });

    test('empty artist+title with empty songId returns null immediately',
        () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => throw StateError('should not be called'),
      );
      final ProviderContainer c = _container(adapter);
      addTearDown(c.dispose);

      final Lyrics? result =
          await c.read(lyricsForProvider('', '', '').future);
      expect(result, isNull);
      expect(adapter.requests, isEmpty);
    });

    test('non-70 Subsonic errors rethrow (error pane, not empty state)',
        () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json('''
{"subsonic-response":{"status":"failed","version":"1.16.1",
  "error":{"code":40,"message":"wrong password"}}}'''),
      );
      final ProviderContainer c = _container(adapter);
      addTearDown(c.dispose);

      await expectLater(
        c.read(lyricsForProvider('so-1', 'Artist', 'Title').future),
        throwsA(isA<NavidromeAuthError>()),
      );
    });
  });
}
