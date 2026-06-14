import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/subsonic_client.dart';
import 'package:heerr/models/recommended_track.dart';
import 'package:heerr/models/subsonic/album.dart';
import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/providers/home/home_providers.dart';
import 'package:heerr/providers/recommendations.dart';

// Route-by-path adapter — records every request so we can assert per-path
// counts and query params. Same shape as the seed-collection / playlist
// mutation test adapters.
class _RouterAdapter implements HttpClientAdapter {
  _RouterAdapter(this._routes);

  final Map<String, FutureOr<ResponseBody> Function(RequestOptions options)>
      _routes;
  final List<RequestOptions> requests = <RequestOptions>[];

  RequestOptions? lastFor(String path) {
    for (int i = requests.length - 1; i >= 0; i--) {
      if (requests[i].path == path) return requests[i];
    }
    return null;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    requests.add(options);
    final FutureOr<ResponseBody> Function(RequestOptions)? fn =
        _routes[options.path];
    if (fn == null) return _ok(<String, dynamic>{});
    return fn(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _ok(Map<String, dynamic> envelopePayload) {
  return ResponseBody.fromString(
    jsonEncode(<String, dynamic>{
      'subsonic-response': <String, dynamic>{
        'status': 'ok',
        'version': '1.16.1',
        ...envelopePayload,
      },
    }),
    200,
    headers: <String, List<String>>{
      'content-type': <String>['application/json'],
    },
  );
}

ResponseBody _albumList(List<Map<String, dynamic>> albums) {
  return _ok(<String, dynamic>{
    'albumList2': <String, dynamic>{'album': albums},
  });
}

ResponseBody _randomSongs(List<Map<String, dynamic>> songs) {
  return _ok(<String, dynamic>{
    'randomSongs': <String, dynamic>{'song': songs},
  });
}

ProviderContainer _container(_RouterAdapter adapter) {
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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('homeRecentProvider', () {
    test('GETs /rest/getAlbumList2.view?type=recent&size=8', () async {
      final _RouterAdapter adapter = _RouterAdapter(
        <String, FutureOr<ResponseBody> Function(RequestOptions)>{
          '/rest/getAlbumList2.view': (_) =>
              _albumList(<Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'al-1',
                  'name': 'Recent Album',
                  'artist': 'Recent Artist',
                  'songCount': 10,
                  'duration': 600,
                },
              ]),
        },
      );
      final ProviderContainer c = _container(adapter);
      addTearDown(c.dispose);

      final List<Album> result = await c.read(homeRecentProvider.future);

      final RequestOptions req = adapter.lastFor('/rest/getAlbumList2.view')!;
      expect(req.queryParameters['type'], 'recent');
      expect(req.queryParameters['size'], 8);
      expect(result, hasLength(1));
      expect(result.first.name, 'Recent Album');
    });

    test('empty albumList2 envelope returns empty list', () async {
      final _RouterAdapter adapter = _RouterAdapter(
        <String, FutureOr<ResponseBody> Function(RequestOptions)>{
          '/rest/getAlbumList2.view': (_) =>
              _albumList(<Map<String, dynamic>>[]),
        },
      );
      final ProviderContainer c = _container(adapter);
      addTearDown(c.dispose);

      final List<Album> result = await c.read(homeRecentProvider.future);
      expect(result, isEmpty);
    });
  });

  group('homeMostPlayedProvider', () {
    test('GETs /rest/getAlbumList2.view?type=frequent&size=8', () async {
      final _RouterAdapter adapter = _RouterAdapter(
        <String, FutureOr<ResponseBody> Function(RequestOptions)>{
          '/rest/getAlbumList2.view': (_) =>
              _albumList(<Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'al-9',
                  'name': 'Frequent Album',
                  'artist': 'Top Artist',
                  'songCount': 12,
                  'duration': 720,
                },
              ]),
        },
      );
      final ProviderContainer c = _container(adapter);
      addTearDown(c.dispose);

      await c.read(homeMostPlayedProvider.future);
      final RequestOptions req = adapter.lastFor('/rest/getAlbumList2.view')!;
      expect(req.queryParameters['type'], 'frequent');
      expect(req.queryParameters['size'], 8);
    });
  });

  group('homeRandomSongsProvider', () {
    test('GETs /rest/getRandomSongs.view?size=20 and parses songs', () async {
      final _RouterAdapter adapter = _RouterAdapter(
        <String, FutureOr<ResponseBody> Function(RequestOptions)>{
          '/rest/getRandomSongs.view': (_) =>
              _randomSongs(<Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'sg-1',
                  'title': 'Random Song',
                  'artist': 'Random Artist',
                },
                <String, dynamic>{
                  'id': 'sg-2',
                  'title': 'Another',
                  'artist': 'Other',
                },
              ]),
        },
      );
      final ProviderContainer c = _container(adapter);
      addTearDown(c.dispose);

      final List<Song> result = await c.read(homeRandomSongsProvider.future);
      final RequestOptions req = adapter.lastFor('/rest/getRandomSongs.view')!;
      expect(req.queryParameters['size'], 20);
      expect(result.map((Song s) => s.id), <String>['sg-1', 'sg-2']);
    });

    test('empty randomSongs envelope returns empty list', () async {
      final _RouterAdapter adapter = _RouterAdapter(
        <String, FutureOr<ResponseBody> Function(RequestOptions)>{
          '/rest/getRandomSongs.view': (_) =>
              _randomSongs(<Map<String, dynamic>>[]),
        },
      );
      final ProviderContainer c = _container(adapter);
      addTearDown(c.dispose);

      final List<Song> result = await c.read(homeRandomSongsProvider.future);
      expect(result, isEmpty);
    });
  });

  group('homeRecommendationsProvider', () {
    test(
      'returns backend recommendations unchanged when non-empty',
      () async {
        final ProviderContainer c = ProviderContainer(
          overrides: <Override>[
            recommendationsProvider.overrideWith(() => _StubRecs(<RecommendedTrack>[
                  const RecommendedTrack(
                    title: 'Rec Song',
                    artist: 'Rec Artist',
                    sourceUrl: 'https://music.youtube.com/watch?v=abc',
                  ),
                ])),
          ],
        );
        addTearDown(c.dispose);

        final HomeRecommendations out =
            await c.read(homeRecommendationsProvider.future);
        expect(out.isFallback, isFalse);
        expect(out.tracks, hasLength(1));
        expect(out.tracks.first.title, 'Rec Song');
      },
    );

    test(
      'falls back to random songs mapped as in-library RecommendedTracks '
      'when the backend returns empty',
      () async {
        final _RouterAdapter adapter = _RouterAdapter(
          <String, FutureOr<ResponseBody> Function(RequestOptions)>{
            '/rest/getRandomSongs.view': (_) =>
                _randomSongs(<Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'rs-1',
                    'title': 'Random A',
                    'artist': 'Artist A',
                    'coverArt': 'ca-1',
                  },
                  <String, dynamic>{
                    'id': 'rs-2',
                    'title': 'Random B',
                    'artist': 'Artist B',
                  },
                  <String, dynamic>{
                    // Missing artist — should be dropped by the mapper
                    // (`artist` field powers the card's subtitle).
                    'id': 'rs-3',
                    'title': 'No artist',
                  },
                ]),
          },
        );
        final ProviderContainer c = ProviderContainer(
          overrides: <Override>[
            subsonicDioClientProvider.overrideWith(
              (Ref<AsyncValue<Dio>> ref) async {
                final Dio dio = Dio(BaseOptions(baseUrl: 'http://navi.test'));
                dio.httpClientAdapter = adapter;
                return dio;
              },
            ),
            recommendationsProvider
                .overrideWith(() => _StubRecs(<RecommendedTrack>[])),
          ],
        );
        addTearDown(c.dispose);

        final HomeRecommendations out =
            await c.read(homeRecommendationsProvider.future);
        expect(out.isFallback, isTrue);
        expect(out.tracks, hasLength(2));
        expect(out.tracks.first.inLibrary, isTrue);
        expect(out.tracks.first.subsonicSongId, 'rs-1');
        expect(out.tracks.first.sourceUrl, isEmpty);
        // coverArt threads through from the random song's `coverArt`.
        expect(out.tracks.first.coverArt, 'ca-1');
        // Songs without coverArt set the field to null.
        expect(out.tracks[1].coverArt, isNull);
      },
    );
  });
}

class _StubRecs extends Recommendations {
  _StubRecs(this._tracks);
  final List<RecommendedTrack> _tracks;

  @override
  Future<List<RecommendedTrack>> build() async => _tracks;
}
