import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/api/client.dart';
import 'package:heerr/models/recommended_track.dart';
import 'package:heerr/models/seed_track.dart';
import 'package:heerr/providers/recommendations.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responder);

  final FutureOr<ResponseBody> Function(RequestOptions options) responder;
  final List<RequestOptions> requests = <RequestOptions>[];
  final List<List<int>> bodies = <List<int>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      final List<int> chunks = <int>[];
      await for (final Uint8List c in requestStream) {
        chunks.addAll(c);
      }
      bodies.add(chunks);
    } else {
      bodies.add(const <int>[]);
    }
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: <String, List<String>>{
      'content-type': <String>['application/json'],
    },
  );
}

ProviderContainer _container({
  required _FakeAdapter adapter,
  required List<SeedTrack> seeds,
}) {
  return ProviderContainer(
    overrides: <Override>[
      dioClientProvider.overrideWith(
        (Ref<AsyncValue<Dio>> ref) async {
          final Dio dio = Dio(BaseOptions(baseUrl: 'http://heerr.test'));
          dio.httpClientAdapter = adapter;
          return dio;
        },
      ),
      seedCollectionProvider.overrideWith((Ref<AsyncValue<List<SeedTrack>>> _) async => seeds),
    ],
  );
}

void main() {
  test('POSTs /recommend with the collected seeds + limit 20', () async {
    final _FakeAdapter adapter = _FakeAdapter(
      (_) => _json(<String, dynamic>{'results': <dynamic>[]}),
    );
    final ProviderContainer c = _container(
      adapter: adapter,
      seeds: <SeedTrack>[
        const SeedTrack(title: 'A', artist: 'X'),
        const SeedTrack(title: 'B', artist: 'Y'),
      ],
    );
    addTearDown(c.dispose);

    await c.read(recommendationsProvider.future);

    expect(adapter.requests, hasLength(1));
    final RequestOptions req = adapter.requests.single;
    expect(req.path, '/recommend');
    expect(req.method, 'POST');

    final Map<String, dynamic> body =
        jsonDecode(utf8.decode(adapter.bodies.single)) as Map<String, dynamic>;
    expect(body['limit'], 20);
    final List<dynamic> seeds = body['seeds'] as List<dynamic>;
    expect(seeds, hasLength(2));
    final Map<String, dynamic> s0 = seeds[0] as Map<String, dynamic>;
    final Map<String, dynamic> s1 = seeds[1] as Map<String, dynamic>;
    expect(s0['title'], 'A');
    expect(s0['artist'], 'X');
    // Backend accepts source_url=null as default; the freezed model may
    // strip nulls from toJson, so accept either shape.
    expect(s0['source_url'], anyOf(isNull, equals(null)));
    expect(s1['title'], 'B');
    expect(s1['artist'], 'Y');
  });

  test('parses the results list into RecommendedTrack objects', () async {
    final _FakeAdapter adapter = _FakeAdapter(
      (_) => _json(<String, dynamic>{
        'results': <Map<String, dynamic>>[
          <String, dynamic>{
            'title': 'Similar Song',
            'artist': 'Other Artist',
            'source_url': 'https://music.youtube.com/watch?v=abc',
            'score': 0.91,
          },
          <String, dynamic>{
            'title': 'No Score',
            'artist': 'Anon',
            'source_url': 'https://music.youtube.com/watch?v=def',
          },
        ],
      }),
    );
    final ProviderContainer c = _container(
      adapter: adapter,
      seeds: <SeedTrack>[const SeedTrack(title: 't', artist: 'a')],
    );
    addTearDown(c.dispose);

    final List<RecommendedTrack> tracks =
        await c.read(recommendationsProvider.future);
    expect(tracks, hasLength(2));
    expect(tracks[0].title, 'Similar Song');
    expect(tracks[0].artist, 'Other Artist');
    expect(tracks[0].sourceUrl, 'https://music.youtube.com/watch?v=abc');
    expect(tracks[0].score, 0.91);
    expect(tracks[0].inLibrary, false);

    expect(tracks[1].score, isNull);
  });

  test('still POSTs when seeds is empty (listenbrainz engine path)', () async {
    final _FakeAdapter adapter = _FakeAdapter(
      (_) => _json(<String, dynamic>{'results': <dynamic>[]}),
    );
    final ProviderContainer c = _container(
      adapter: adapter,
      seeds: const <SeedTrack>[],
    );
    addTearDown(c.dispose);

    final List<RecommendedTrack> tracks =
        await c.read(recommendationsProvider.future);

    expect(tracks, isEmpty);
    expect(adapter.requests, hasLength(1));
    final Map<String, dynamic> body =
        jsonDecode(utf8.decode(adapter.bodies.single)) as Map<String, dynamic>;
    expect((body['seeds'] as List<dynamic>), isEmpty);
    expect(body['limit'], 20);
  });

  test('refresh() re-issues the POST', () async {
    final _FakeAdapter adapter = _FakeAdapter(
      (_) => _json(<String, dynamic>{'results': <dynamic>[]}),
    );
    final ProviderContainer c = _container(
      adapter: adapter,
      seeds: <SeedTrack>[const SeedTrack(title: 't', artist: 'a')],
    );
    addTearDown(c.dispose);

    await c.read(recommendationsProvider.future);
    final int before = adapter.requests.length;

    await c.read(recommendationsProvider.notifier).refresh();

    expect(adapter.requests.length, greaterThan(before),
        reason: 'refresh must trigger at least one new POST');
  });

  test('backend error surfaces as ApiError', () async {
    final _FakeAdapter adapter = _FakeAdapter(
      (_) => ResponseBody.fromString(
        jsonEncode(<String, dynamic>{'detail': 'engine down'}),
        503,
        headers: <String, List<String>>{
          'content-type': <String>['application/json'],
        },
      ),
    );
    final ProviderContainer c = _container(
      adapter: adapter,
      seeds: <SeedTrack>[const SeedTrack(title: 't', artist: 'a')],
    );
    addTearDown(c.dispose);

    await expectLater(
      c.read(recommendationsProvider.future),
      throwsA(isA<ApiError>()),
    );
  });
}
