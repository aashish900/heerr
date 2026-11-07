import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/client.dart';
import 'package:heerr/api/subsonic_client.dart';
import 'package:heerr/models/mix.dart';
import 'package:heerr/models/recommended_track.dart';
import 'package:heerr/models/seed_track.dart';
import 'package:heerr/providers/mixes.dart';
import 'package:heerr/providers/recommendations.dart';

/// Backend adapter: records each request + decoded JSON body, answers via
/// [responder].
class _BackendAdapter implements HttpClientAdapter {
  _BackendAdapter(this.responder);

  final FutureOr<ResponseBody> Function(RequestOptions options) responder;
  final List<RequestOptions> requests = <RequestOptions>[];
  final List<Map<String, dynamic>?> bodies = <Map<String, dynamic>?>[];

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
      bodies.add(jsonDecode(utf8.decode(chunks)) as Map<String, dynamic>);
    } else {
      bodies.add(null);
    }
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

/// Subsonic search3: a song match when the query contains an owned key.
class _Search3Adapter implements HttpClientAdapter {
  _Search3Adapter(this.owned);
  final Set<String> owned;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    final String q = options.queryParameters['query'] as String? ?? '';
    final bool hit = owned.any(q.contains);
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'subsonic-response': <String, dynamic>{
          'status': 'ok',
          'version': '1.16.1',
          'searchResult3': hit
              ? <String, dynamic>{
                  'song': <Map<String, dynamic>>[
                    <String, dynamic>{'id': 'lib-1', 'title': 'x', 'artist': 'y'},
                  ],
                }
              : <String, dynamic>{},
        },
      }),
      200,
      headers: <String, List<String>>{
        'content-type': <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, {int status = 200}) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: <String, List<String>>{
        'content-type': <String>['application/json'],
      },
    );

Map<String, dynamic> _mixJson(List<String> titles, {bool personalized = true}) =>
    <String, dynamic>{
      'id': 'chill',
      'title': 'Chill Mix',
      'personalized': personalized,
      'results': <Map<String, dynamic>>[
        for (final String t in titles)
          <String, dynamic>{
            'title': t,
            'artist': 'Artist $t',
            'source_url': 'https://music.youtube.com/watch?v=$t',
          },
      ],
    };

ProviderContainer _container({
  required _BackendAdapter backend,
  List<SeedTrack> seeds = const <SeedTrack>[],
  Set<String> owned = const <String>{},
}) {
  return ProviderContainer(
    overrides: <Override>[
      dioClientProvider.overrideWith((Ref<AsyncValue<Dio>> ref) async {
        return Dio(BaseOptions(baseUrl: 'http://heerr.test'))
          ..httpClientAdapter = backend;
      }),
      subsonicDioClientProvider.overrideWith((Ref<AsyncValue<Dio>> ref) async {
        return Dio(BaseOptions(baseUrl: 'http://navi.test'))
          ..httpClientAdapter = _Search3Adapter(owned);
      }),
      seedCollectionProvider
          .overrideWith((Ref<AsyncValue<List<SeedTrack>>> _) async => seeds),
    ],
  );
}

void main() {
  test('mixVibesProvider lists the backend vibes', () async {
    final _BackendAdapter backend = _BackendAdapter(
      (_) => _json(<Map<String, String>>[
        <String, String>{'id': 'chill', 'title': 'Chill Mix'},
        <String, String>{'id': 'sleep', 'title': 'Sleep Mix'},
      ]),
    );
    final ProviderContainer c = _container(backend: backend);
    addTearDown(c.dispose);

    final List<MixVibe> vibes = await c.read(mixVibesProvider.future);
    expect(vibes.map((MixVibe v) => v.title).toList(),
        <String>['Chill Mix', 'Sleep Mix']);
    expect(backend.requests.single.path, '/recommend/mixes');
  });

  test('mix sends ALL seeds (not a sample), limit 50, variant 0', () async {
    final List<SeedTrack> seeds = List<SeedTrack>.generate(
        20, (int i) => SeedTrack(artist: 'Artist $i', weight: 0.7));
    final _BackendAdapter backend =
        _BackendAdapter((_) => _json(_mixJson(<String>['a'])));
    final ProviderContainer c = _container(backend: backend, seeds: seeds);
    addTearDown(c.dispose);

    await c.read(mixNotifierProvider('chill').future);

    expect(backend.requests.single.path, '/recommend/mixes/chill');
    final Map<String, dynamic> body = backend.bodies.single!;
    expect((body['seeds'] as List<dynamic>), hasLength(20));
    expect(body['limit'], 50);
    expect(body['variant'], 0);
  });

  test('mix drops songs already in the library, keeps order', () async {
    final _BackendAdapter backend =
        _BackendAdapter((_) => _json(_mixJson(<String>['a', 'owned', 'b'])));
    final ProviderContainer c = _container(
        backend: backend, owned: <String>{'Artist owned owned'});
    addTearDown(c.dispose);

    final MixResponse mix = await c.read(mixNotifierProvider('chill').future);
    expect(mix.results.map((RecommendedTrack t) => t.title).toList(),
        <String>['a', 'b']);
    expect(mix.title, 'Chill Mix');
    expect(mix.personalized, isTrue);
  });

  test('regenerate posts the next variant each time', () async {
    final _BackendAdapter backend =
        _BackendAdapter((_) => _json(_mixJson(<String>['a'])));
    final ProviderContainer c = _container(backend: backend);
    addTearDown(c.dispose);

    await c.read(mixNotifierProvider('chill').future);
    await c.read(mixNotifierProvider('chill').notifier).regenerate();
    await c.read(mixNotifierProvider('chill').notifier).regenerate();

    expect(backend.bodies.map((Map<String, dynamic>? b) => b!['variant']).toList(),
        <int>[0, 1, 2]);
  });

  test('each vibe is its own mix', () async {
    final _BackendAdapter backend =
        _BackendAdapter((_) => _json(_mixJson(<String>['a'])));
    final ProviderContainer c = _container(backend: backend);
    addTearDown(c.dispose);

    await c.read(mixNotifierProvider('chill').future);
    await c.read(mixNotifierProvider('party').future);
    expect(backend.requests.map((RequestOptions r) => r.path).toList(),
        <String>['/recommend/mixes/chill', '/recommend/mixes/party']);
  });

  test('backend error surfaces as AsyncError', () async {
    final _BackendAdapter backend = _BackendAdapter(
        (_) => _json(<String, String>{'detail': 'mood gone'}, status: 503));
    final ProviderContainer c = _container(backend: backend);
    addTearDown(c.dispose);

    await expectLater(
        c.read(mixNotifierProvider('heartbreak').future), throwsA(anything));
    expect(c.read(mixNotifierProvider('heartbreak')).hasError, isTrue);
  });
}
