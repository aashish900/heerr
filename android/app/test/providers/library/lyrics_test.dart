import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/api/subsonic_client.dart';
import 'package:heerr/models/subsonic/lyrics.dart';
import 'package:heerr/offline/offline_paths.dart';
import 'package:heerr/providers/library/lyrics.dart';
import 'package:heerr/services/lyrics_service.dart';

import '../../support/cred_test_support.dart';

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


ProviderContainer _container(
  _FakeAdapter subsonicAdapter, {
  // #26: the provider now resolves the offline lyrics cache; a temp docs
  // dir keeps path_provider out of unit tests. Pass the same dir across
  // two containers to simulate "cached earlier, offline now".
  Directory? docsDir,
  // When set, the active profile carries Navidrome creds so the per-server
  // cache path resolves; null creds make the cache a no-op (pre-#26
  // behaviour, which the older tests in this file assert).
  bool withCreds = false,
  _FakeAdapter? lrcLibAdapter,
}) {
  final Directory docs =
      docsDir ?? Directory.systemTemp.createTempSync('heerr-lyrics-test-');
  return ProviderContainer(
    overrides: <Override>[
      applicationDocumentsDirectoryProvider
          .overrideWith((ApplicationDocumentsDirectoryRef ref) async => docs),
      if (withCreds) activeProfileOverride(),
      subsonicDioClientProvider.overrideWith(
        (Ref<AsyncValue<Dio>> ref) async {
          final Dio dio = Dio(BaseOptions(baseUrl: 'http://navi.test'));
          dio.httpClientAdapter = subsonicAdapter;
          return dio;
        },
      ),
      if (lrcLibAdapter != null)
        lyricsServiceProvider.overrideWith(
          (Ref<AsyncValue<LyricsService>> ref) async {
            final Dio subsonic = await ref.watch(
              subsonicDioClientProvider.future,
            );
            final Dio lrc = Dio(BaseOptions(baseUrl: 'http://lrclib.test'));
            lrc.httpClientAdapter = lrcLibAdapter;
            return LyricsService(subsonic, lrcLibDio: lrc);
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

  group('synced lyrics (#26)', () {
    test('Navidrome structuredLyrics with synced:true carries timed lines',
        () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json('''
{"subsonic-response":{"status":"ok","version":"1.16.1",
  "lyricsList":{"structuredLyrics":[
    {"synced":true,"line":[
      {"start":0,"value":"Line one"},
      {"start":2500,"value":"Line two"}]}
  ]}}}'''),
      );
      final ProviderContainer c = _container(adapter);
      addTearDown(c.dispose);

      final Lyrics? result = await c
          .read(lyricsForProvider('so-1', 'Artist', 'Title').future);
      expect(result!.lines, const <LyricsLine>[
        LyricsLine(start: 0, value: 'Line one'),
        LyricsLine(start: 2500, value: 'Line two'),
      ]);
      expect(result.value, 'Line one\nLine two');
    });

    test('unsynced structuredLyrics yields null lines (plain rendering)',
        () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json('''
{"subsonic-response":{"status":"ok","version":"1.16.1",
  "lyricsList":{"structuredLyrics":[
    {"line":[{"value":"Just text"}]}
  ]}}}'''),
      );
      final ProviderContainer c = _container(adapter);
      addTearDown(c.dispose);

      final Lyrics? result = await c
          .read(lyricsForProvider('so-1', 'Artist', 'Title').future);
      expect(result!.lines, isNull);
    });

    test('LRCLib syncedLyrics parses into timed lines', () async {
      final _FakeAdapter navidrome = _FakeAdapter(
        (_) => _json('''
{"subsonic-response":{"status":"failed","version":"1.16.1",
  "error":{"code":70,"message":"no lyrics"}}}'''),
      );
      final _FakeAdapter lrclib = _FakeAdapter(
        (_) => _json('''
{"plainLyrics":"Hello\\nWorld",
 "syncedLyrics":"[00:01.50] Hello\\n[00:03.00] World"}'''),
      );
      final ProviderContainer c =
          _container(navidrome, lrcLibAdapter: lrclib);
      addTearDown(c.dispose);

      final Lyrics? result = await c
          .read(lyricsForProvider('so-1', 'Artist', 'Title').future);
      expect(result!.value, 'Hello\nWorld');
      expect(result.lines, const <LyricsLine>[
        LyricsLine(start: 1500, value: 'Hello'),
        LyricsLine(start: 3000, value: 'World'),
      ]);
    });
  });

  group('offline lyrics cache (#26)', () {
    test('successful resolve writes the per-server cache file', () async {
      final Directory docs =
          Directory.systemTemp.createTempSync('heerr-lyrics-test-');
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json('''
{"subsonic-response":{"status":"ok","version":"1.16.1",
  "lyricsList":{"structuredLyrics":[
    {"synced":true,"line":[{"start":0,"value":"Cached line"}]}
  ]}}}'''),
      );
      final ProviderContainer c =
          _container(adapter, docsDir: docs, withCreds: true);
      addTearDown(c.dispose);

      await c.read(lyricsForProvider('so-1', 'Artist', 'Title').future);

      final String key = OfflinePaths.serverKey(
        navidromeBaseUrl: 'http://navi:4533',
        navidromeUsername: 'me',
      );
      final File cached =
          File('${docs.path}/offline/$key/lyrics/so-1.json');
      expect(await cached.exists(), isTrue);
    });

    test('network failure serves the cache instead of throwing', () async {
      final Directory docs =
          Directory.systemTemp.createTempSync('heerr-lyrics-test-');
      // Pass 1 — online, synced lyrics cached.
      final _FakeAdapter online = _FakeAdapter(
        (_) => _json('''
{"subsonic-response":{"status":"ok","version":"1.16.1",
  "lyricsList":{"structuredLyrics":[
    {"synced":true,"line":[{"start":0,"value":"Cached line"}]}
  ]}}}'''),
      );
      final ProviderContainer first =
          _container(online, docsDir: docs, withCreds: true);
      await first
          .read(lyricsForProvider('so-1', 'Artist', 'Title').future);
      first.dispose();

      // Pass 2 — Navidrome errors (auth stands in for unreachable; both
      // surface as ApiError). Cache must win over the error pane.
      final _FakeAdapter offline = _FakeAdapter(
        (_) => _json('''
{"subsonic-response":{"status":"failed","version":"1.16.1",
  "error":{"code":40,"message":"wrong password"}}}'''),
      );
      final ProviderContainer second =
          _container(offline, docsDir: docs, withCreds: true);
      addTearDown(second.dispose);

      final Lyrics? result = await second
          .read(lyricsForProvider('so-1', 'Artist', 'Title').future);
      expect(result!.value, 'Cached line');
      expect(result.lines, const <LyricsLine>[
        LyricsLine(start: 0, value: 'Cached line'),
      ]);
    });

    test('network failure with no cache still rethrows', () async {
      final _FakeAdapter offline = _FakeAdapter(
        (_) => _json('''
{"subsonic-response":{"status":"failed","version":"1.16.1",
  "error":{"code":40,"message":"wrong password"}}}'''),
      );
      final ProviderContainer c = _container(offline, withCreds: true);
      addTearDown(c.dispose);

      await expectLater(
        c.read(lyricsForProvider('so-1', 'Artist', 'Title').future),
        throwsA(isA<NavidromeAuthError>()),
      );
    });
  });
}
