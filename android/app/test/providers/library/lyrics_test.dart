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
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    lastRequest = options;
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

ProviderContainer _container(_FakeAdapter adapter) {
  return ProviderContainer(
    overrides: <Override>[
      subsonicDioClientProvider.overrideWith(
        (Ref<AsyncValue<Dio>> ref) async {
          final Dio dio = Dio(BaseOptions(baseUrl: 'http://navi.test'));
          dio.httpClientAdapter = adapter;
          return dio;
        },
      ),
    ],
  );
}

void main() {
  group('lyricsForProvider', () {
    test('hits /rest/getLyrics.view with artist+title and parses payload',
        () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json('''
{"subsonic-response":{"status":"ok","version":"1.16.1",
  "lyrics":{"artist":"Tame Impala","title":"Let It Happen",
            "value":"It's always the same\\nNever gonna change"}}}'''),
      );
      final ProviderContainer c = _container(adapter);
      addTearDown(c.dispose);

      final Lyrics? result = await c
          .read(lyricsForProvider('Tame Impala', 'Let It Happen').future);

      expect(adapter.lastRequest!.path, '/rest/getLyrics.view');
      expect(adapter.lastRequest!.queryParameters['artist'], 'Tame Impala');
      expect(adapter.lastRequest!.queryParameters['title'], 'Let It Happen');
      expect(result, isNotNull);
      expect(result!.value, contains('Never gonna change'));
    });

    test('Subsonic code 70 (not found) → null (empty state, not error)',
        () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json('''
{"subsonic-response":{"status":"failed","version":"1.16.1",
  "error":{"code":70,"message":"no lyrics"}}}'''),
      );
      final ProviderContainer c = _container(adapter);
      addTearDown(c.dispose);

      final Lyrics? result =
          await c.read(lyricsForProvider('A', 'B').future);
      expect(result, isNull);
    });

    test('empty value in envelope → null', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json('''
{"subsonic-response":{"status":"ok","version":"1.16.1",
  "lyrics":{"artist":"X","title":"Y","value":""}}}'''),
      );
      final ProviderContainer c = _container(adapter);
      addTearDown(c.dispose);

      final Lyrics? result =
          await c.read(lyricsForProvider('X', 'Y').future);
      expect(result, isNull);
    });

    test('whitespace-only value → null', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json('''
{"subsonic-response":{"status":"ok","version":"1.16.1",
  "lyrics":{"value":"   \\n  \\t  "}}}'''),
      );
      final ProviderContainer c = _container(adapter);
      addTearDown(c.dispose);

      final Lyrics? result =
          await c.read(lyricsForProvider('X', 'Y').future);
      expect(result, isNull);
    });

    test('missing lyrics block → null', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json(
            '{"subsonic-response":{"status":"ok","version":"1.16.1"}}'),
      );
      final ProviderContainer c = _container(adapter);
      addTearDown(c.dispose);

      final Lyrics? result =
          await c.read(lyricsForProvider('X', 'Y').future);
      expect(result, isNull);
    });

    test('empty artist or title returns null without an HTTP call', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => throw StateError('should not be called'),
      );
      final ProviderContainer c = _container(adapter);
      addTearDown(c.dispose);

      expect(
        await c.read(lyricsForProvider('', 'Title').future),
        isNull,
      );
      expect(
        await c.read(lyricsForProvider('Artist', '').future),
        isNull,
      );
      expect(
        await c.read(lyricsForProvider('   ', 'Title').future),
        isNull,
      );
      expect(adapter.lastRequest, isNull);
    });

    test('other Subsonic errors propagate as ApiError (not null)',
        () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json('''
{"subsonic-response":{"status":"failed","version":"1.16.1",
  "error":{"code":40,"message":"wrong password"}}}'''),
      );
      final ProviderContainer c = _container(adapter);
      addTearDown(c.dispose);

      await expectLater(
        c.read(lyricsForProvider('A', 'B').future),
        throwsA(isA<NavidromeAuthError>()),
      );
    });
  });
}
