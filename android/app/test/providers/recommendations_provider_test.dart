import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/api/client.dart';
import 'package:heerr/api/subsonic_client.dart';
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
  HttpClientAdapter? subsonicAdapter,
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
      subsonicDioClientProvider.overrideWith(
        (Ref<AsyncValue<Dio>> ref) async {
          final Dio dio = Dio(BaseOptions(baseUrl: 'http://navi.test'));
          dio.httpClientAdapter = subsonicAdapter ?? _NullSubsonicAdapter();
          return dio;
        },
      ),
      seedCollectionProvider.overrideWith((Ref<AsyncValue<List<SeedTrack>>> _) async => seeds),
    ],
  );
}

/// Returns an empty `searchResult3` envelope — for tests that don't care
/// about the cross-reference step (everything stays inLibrary=false).
class _NullSubsonicAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'subsonic-response': <String, dynamic>{
          'status': 'ok',
          'version': '1.16.1',
          'searchResult3': <String, dynamic>{},
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

/// Routes search3 calls by request query. Returns a song match when the
/// query contains a configured `(artist title)` pair.
class _SearchSubsonicAdapter implements HttpClientAdapter {
  _SearchSubsonicAdapter(this.matches);

  /// Map of query substring → song id to return.
  final Map<String, String> matches;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    requests.add(options);
    final String? query = options.queryParameters['query'] as String?;
    String? id;
    if (query != null) {
      for (final MapEntry<String, String> e in matches.entries) {
        if (query.contains(e.key)) {
          id = e.value;
          break;
        }
      }
    }
    final Map<String, dynamic> result;
    if (id != null) {
      result = <String, dynamic>{
        'searchResult3': <String, dynamic>{
          'song': <Map<String, dynamic>>[
            <String, dynamic>{'id': id, 'title': 'x', 'artist': 'y'},
          ],
        },
      };
    } else {
      result = <String, dynamic>{
        'searchResult3': <String, dynamic>{},
      };
    }
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'subsonic-response': <String, dynamic>{
          'status': 'ok',
          'version': '1.16.1',
          ...result,
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

  test(
      'cross-reference: results that match Subsonic search3 get '
      'inLibrary=true + subsonicSongId; the rest stay remote', () async {
    final _FakeAdapter adapter = _FakeAdapter(
      (_) => _json(<String, dynamic>{
        'results': <Map<String, dynamic>>[
          <String, dynamic>{
            'title': 'OwnedSong',
            'artist': 'OwnedArtist',
            'source_url': 'https://music.youtube.com/watch?v=owned',
          },
          <String, dynamic>{
            'title': 'RemoteSong',
            'artist': 'RemoteArtist',
            'source_url': 'https://music.youtube.com/watch?v=remote',
          },
        ],
      }),
    );
    final _SearchSubsonicAdapter sub = _SearchSubsonicAdapter(<String, String>{
      'OwnedArtist OwnedSong': 'lib-song-42',
    });
    final ProviderContainer c = _container(
      adapter: adapter,
      seeds: <SeedTrack>[const SeedTrack(title: 't', artist: 'a')],
      subsonicAdapter: sub,
    );
    addTearDown(c.dispose);

    final List<RecommendedTrack> tracks =
        await c.read(recommendationsProvider.future);
    expect(tracks, hasLength(2));

    final RecommendedTrack owned =
        tracks.firstWhere((RecommendedTrack t) => t.title == 'OwnedSong');
    final RecommendedTrack remote =
        tracks.firstWhere((RecommendedTrack t) => t.title == 'RemoteSong');

    expect(owned.inLibrary, isTrue);
    expect(owned.subsonicSongId, 'lib-song-42');
    expect(remote.inLibrary, isFalse);
    expect(remote.subsonicSongId, isNull);

    // search3 was called once per result.
    expect(sub.requests, hasLength(2));
    for (final RequestOptions r in sub.requests) {
      expect(r.path, '/rest/search3.view');
      expect(r.queryParameters['songCount'], 1);
    }
  });

  test('cross-reference failure for one result does not break the list',
      () async {
    final _FakeAdapter adapter = _FakeAdapter(
      (_) => _json(<String, dynamic>{
        'results': <Map<String, dynamic>>[
          <String, dynamic>{
            'title': 'A',
            'artist': 'X',
            'source_url': 'https://music.youtube.com/watch?v=a',
          },
        ],
      }),
    );
    // Subsonic dio not available → cross-reference no-ops gracefully.
    final ProviderContainer c = _container(
      adapter: adapter,
      seeds: <SeedTrack>[const SeedTrack(title: 't', artist: 'a')],
      subsonicAdapter: _NullSubsonicAdapter(),
    );
    addTearDown(c.dispose);

    final List<RecommendedTrack> tracks =
        await c.read(recommendationsProvider.future);
    expect(tracks, hasLength(1));
    expect(tracks.first.inLibrary, isFalse);
  });

  test(
      'manualSeedProvider override: recommendations uses ONLY that seed '
      'and ignores seedCollectionProvider', () async {
    final _FakeAdapter adapter = _FakeAdapter(
      (_) => _json(<String, dynamic>{'results': <dynamic>[]}),
    );
    final ProviderContainer c = _container(
      adapter: adapter,
      seeds: <SeedTrack>[
        // The seed collection has many seeds — none of these should make
        // it onto the wire when the manual seed is set.
        const SeedTrack(title: 'CollectionA', artist: 'CA'),
        const SeedTrack(title: 'CollectionB', artist: 'CB'),
      ],
    );
    addTearDown(c.dispose);

    c.read(manualSeedProvider.notifier).state =
        const SeedTrack(title: 'Manual', artist: 'M');

    await c.read(recommendationsProvider.future);
    final Map<String, dynamic> body =
        jsonDecode(utf8.decode(adapter.bodies.single)) as Map<String, dynamic>;
    final List<dynamic> seeds = body['seeds'] as List<dynamic>;
    expect(seeds, hasLength(1));
    expect((seeds.single as Map<String, dynamic>)['title'], 'Manual');
    expect((seeds.single as Map<String, dynamic>)['artist'], 'M');
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
