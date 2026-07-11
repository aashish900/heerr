import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/subsonic_client.dart';
import 'package:heerr/models/subsonic/album.dart';
import 'package:heerr/providers/home/home_providers.dart';

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

  group('homeNewestProvider', () {
    test('GETs /rest/getAlbumList2.view?type=newest&size=8', () async {
      final _RouterAdapter adapter = _RouterAdapter(
        <String, FutureOr<ResponseBody> Function(RequestOptions)>{
          '/rest/getAlbumList2.view': (_) =>
              _albumList(<Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'al-1',
                  'name': 'New Album',
                  'artist': 'New Artist',
                  'songCount': 10,
                  'duration': 600,
                },
              ]),
        },
      );
      final ProviderContainer c = _container(adapter);
      addTearDown(c.dispose);

      final List<Album> result = await c.read(homeNewestProvider.future);

      final RequestOptions req = adapter.lastFor('/rest/getAlbumList2.view')!;
      expect(req.queryParameters['type'], 'newest');
      expect(req.queryParameters['size'], 8);
      expect(result, hasLength(1));
      expect(result.first.name, 'New Album');
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

      final List<Album> result = await c.read(homeNewestProvider.future);
      expect(result, isEmpty);
    });
  });

  group('recentlyAddedFullProvider', () {
    test('GETs /rest/getAlbumList2.view?type=newest&size=50', () async {
      final _RouterAdapter adapter = _RouterAdapter(
        <String, FutureOr<ResponseBody> Function(RequestOptions)>{
          '/rest/getAlbumList2.view': (_) =>
              _albumList(<Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'al-9',
                  'name': 'Full Album',
                  'artist': 'Full Artist',
                  'songCount': 12,
                  'duration': 720,
                },
              ]),
        },
      );
      final ProviderContainer c = _container(adapter);
      addTearDown(c.dispose);

      await c.read(recentlyAddedFullProvider.future);
      final RequestOptions req = adapter.lastFor('/rest/getAlbumList2.view')!;
      expect(req.queryParameters['type'], 'newest');
      expect(req.queryParameters['size'], 50);
    });
  });
}
