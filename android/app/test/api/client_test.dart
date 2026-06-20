import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/api/client.dart';
import 'package:heerr/models/profile.dart';
import 'package:heerr/providers/profiles/profile_registry.dart';
import 'package:heerr/providers/secure_storage.dart';

// ---------------------------------------------------------------------------
// In-process HTTP adapter — much smaller than http_mock_adapter and avoids
// adding a dep. Each test installs a `responder` that takes the request and
// returns a `ResponseBody` describing the canned response.
// ---------------------------------------------------------------------------
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

ResponseBody _json(
  int statusCode,
  Map<String, dynamic> body, {
  Map<String, List<String>>? headers,
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      'content-type': <String>['application/json'],
      ...?headers,
    },
  );
}

Dio _dioWith(_FakeAdapter adapter, {String? token}) {
  // Default `validateStatus` (2xx success, other → DioException with the
  // response populated) is what we want; `apiCall` and `mapDioErrorToApiError`
  // expect non-2xx to surface as `DioException.badResponse` with a body.
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
  dio.httpClientAdapter = adapter;
  if (token != null) {
    dio.interceptors.add(BearerAuthInterceptor(() => token));
  }
  return dio;
}

void main() {
  group('BearerAuthInterceptor', () {
    test('injects Authorization header when token is non-empty', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json(200, <String, dynamic>{'ok': true}),
      );
      final Dio dio = _dioWith(adapter, token: 'secret-token');

      await dio.get<dynamic>('/health');

      expect(
        adapter.lastRequest!.headers['Authorization'],
        'Bearer secret-token',
      );
    });

    test('omits Authorization header when token is null', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json(200, <String, dynamic>{'ok': true}),
      );
      final Dio dio = _dioWith(adapter, token: null);

      await dio.get<dynamic>('/health');

      expect(adapter.lastRequest!.headers.containsKey('Authorization'), isFalse);
    });

    test('omits Authorization header when token is empty', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json(200, <String, dynamic>{'ok': true}),
      );
      final Dio dio = _dioWith(adapter, token: '');

      await dio.get<dynamic>('/health');

      expect(adapter.lastRequest!.headers.containsKey('Authorization'), isFalse);
    });
  });

  group('apiCall — happy path', () {
    test('returns parsed body on 200', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json(200, <String, dynamic>{'status': 'ok'}),
      );
      final Dio dio = _dioWith(adapter);

      final Map<String, dynamic> result = await apiCall<Map<String, dynamic>>(
        () => dio.get<dynamic>('/health'),
        (dynamic data) => Map<String, dynamic>.from(data as Map<dynamic, dynamic>),
      );

      expect(result, <String, dynamic>{'status': 'ok'});
    });
  });

  group('apiCall — error mapping', () {
    test('401 → UnauthorizedError with backend detail', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json(401, <String, dynamic>{'detail': 'unknown or revoked token'}),
      );
      final Dio dio = _dioWith(adapter);

      await expectLater(
        apiCall<dynamic>(
          () => dio.get<dynamic>('/queue'),
          (dynamic d) => d,
        ),
        throwsA(
          isA<UnauthorizedError>().having(
            (UnauthorizedError e) => e.detail,
            'detail',
            'unknown or revoked token',
          ),
        ),
      );
    });

    test('403 → ForbiddenError', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json(403, <String, dynamic>{'detail': 'admin required'}),
      );
      final Dio dio = _dioWith(adapter);

      await expectLater(
        apiCall<dynamic>(() => dio.post<dynamic>('/download'), (dynamic d) => d),
        throwsA(
          isA<ForbiddenError>().having(
            (ForbiddenError e) => e.detail,
            'detail',
            'admin required',
          ),
        ),
      );
    });

    test('422 → UnprocessableError extracts first list item as detail', () async {
      // Pydantic returns `{"detail": [{"loc": [...], "msg": "..."}, ...]}`.
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json(422, <String, dynamic>{
          'detail': <Map<String, dynamic>>[
            <String, dynamic>{'msg': 'invalid spotify URI'},
          ],
        }),
      );
      final Dio dio = _dioWith(adapter);

      await expectLater(
        apiCall<dynamic>(() => dio.post<dynamic>('/download'), (dynamic d) => d),
        throwsA(isA<UnprocessableError>()),
      );
    });

    test('503 → RateLimitedError with parsed Retry-After', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json(
          503,
          <String, dynamic>{'detail': 'upstream rate limited'},
          headers: <String, List<String>>{
            'retry-after': <String>['7'],
          },
        ),
      );
      final Dio dio = _dioWith(adapter);

      await expectLater(
        apiCall<dynamic>(() => dio.post<dynamic>('/search'), (dynamic d) => d),
        throwsA(
          isA<RateLimitedError>()
              .having(
                (RateLimitedError e) => e.retryAfter,
                'retryAfter',
                const Duration(seconds: 7),
              )
              .having(
                (RateLimitedError e) => e.detail,
                'detail',
                'upstream rate limited',
              ),
        ),
      );
    });

    test('503 without Retry-After → defaults to 30s', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json(503, <String, dynamic>{'detail': 'rate limited'}),
      );
      final Dio dio = _dioWith(adapter);

      await expectLater(
        apiCall<dynamic>(() => dio.post<dynamic>('/search'), (dynamic d) => d),
        throwsA(
          isA<RateLimitedError>().having(
            (RateLimitedError e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 30),
          ),
        ),
      );
    });

    test('500 → HttpStatusError (fallback bucket)', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json(500, <String, dynamic>{'detail': 'internal server error'}),
      );
      final Dio dio = _dioWith(adapter);

      await expectLater(
        apiCall<dynamic>(() => dio.get<dynamic>('/queue'), (dynamic d) => d),
        throwsA(
          isA<HttpStatusError>().having(
            (HttpStatusError e) => e.statusCode,
            'statusCode',
            500,
          ),
        ),
      );
    });

    test('connection error → NetworkError', () async {
      // Dio raises DioExceptionType.connectionError when the adapter throws
      // a SocketException-like error. We synthesise via a thrown DioException.
      final Dio dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
      dio.httpClientAdapter = _FakeAdapter((RequestOptions opts) {
        throw DioException(
          requestOptions: opts,
          type: DioExceptionType.connectionError,
          error: 'no route to host',
        );
      });

      await expectLater(
        apiCall<dynamic>(() => dio.get<dynamic>('/health'), (dynamic d) => d),
        throwsA(isA<NetworkError>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // dioClientProvider end-to-end: active profile → dio wired with the right
  // baseUrl + interceptor token. A1: credentials come exclusively from the
  // active Profile; there is no longer a settings/legacy-key path.
  // -------------------------------------------------------------------------
  group('dioClientProvider', () {
    ProviderContainer makeContainer(_InMemoryStorage store) {
      return ProviderContainer(
        overrides: <Override>[
          secureStorageProvider.overrideWith((Ref<SecureStorage> ref) => store),
        ],
      );
    }

    Profile profileWith({required String baseUrl, required String token}) {
      final DateTime t = DateTime.utc(2026, 6, 19);
      return Profile(
        id: 'p1',
        displayName: 'me',
        heerrBaseUrl: baseUrl,
        heerrBearerToken: token,
        navidromeBaseUrl: 'http://navi:4533',
        navidromeUsername: 'me',
        navidromePassword: 'pw',
        createdAt: t,
        lastUsedAt: t,
      );
    }

    test('builds dio with baseUrl + token from the active profile', () async {
      final _InMemoryStorage store = _InMemoryStorage();
      final ProviderContainer c = makeContainer(store);
      addTearDown(c.dispose);

      final ProfileRegistry reg = c.read(profileRegistryProvider.notifier);
      await reg.addProfile(
        profileWith(baseUrl: 'http://my-tailnet:8000/api/v1', token: 'tok-xyz'),
      );
      await reg.setActive('p1');

      final Dio dio = await c.read(dioClientProvider.future);

      expect(dio.options.baseUrl, 'http://my-tailnet:8000/api/v1');
      expect(
        dio.interceptors
            .whereType<BearerAuthInterceptor>()
            .single
            .tokenResolver(),
        'tok-xyz',
      );
    });

    test('A3: token rotation on the same base URL does NOT rebuild the dio; '
        'the interceptor resolves the new token per request', () async {
      final _InMemoryStorage store = _InMemoryStorage();
      final ProviderContainer c = makeContainer(store);
      addTearDown(c.dispose);

      // Pin the provider alive so autodispose doesn't tear the dio down
      // between reads — we want to assert the SAME instance survives.
      c.listen(dioClientProvider, (_, _) {}, fireImmediately: true);

      final ProfileRegistry reg = c.read(profileRegistryProvider.notifier);
      await reg.addProfile(
        profileWith(baseUrl: 'http://x:8000/api/v1', token: 'first'),
      );
      await reg.setActive('p1');

      final Dio dio1 = await c.read(dioClientProvider.future);
      final BearerAuthInterceptor interceptor =
          dio1.interceptors.whereType<BearerAuthInterceptor>().single;
      expect(interceptor.tokenResolver(), 'first');

      // Re-add the same profile id with a rotated token (same base URL).
      await reg.addProfile(
        profileWith(baseUrl: 'http://x:8000/api/v1', token: 'second'),
      );
      final Dio dio2 = await c.read(dioClientProvider.future);

      // Same base URL → no rebuild (A3: dio only rebuilds on base-URL change).
      expect(identical(dio1, dio2), isTrue);
      // …but the interceptor now resolves the rotated token.
      expect(interceptor.tokenResolver(), 'second');
    });

    test('A3: a base-URL change DOES rebuild the dio', () async {
      final _InMemoryStorage store = _InMemoryStorage();
      final ProviderContainer c = makeContainer(store);
      addTearDown(c.dispose);

      c.listen(dioClientProvider, (_, _) {}, fireImmediately: true);

      final ProfileRegistry reg = c.read(profileRegistryProvider.notifier);
      await reg.addProfile(
        profileWith(baseUrl: 'http://x:8000/api/v1', token: 'tok'),
      );
      await reg.setActive('p1');
      final Dio dio1 = await c.read(dioClientProvider.future);

      await reg.addProfile(
        profileWith(baseUrl: 'http://y:8000/api/v1', token: 'tok'),
      );
      final Dio dio2 = await c.read(dioClientProvider.future);

      expect(identical(dio1, dio2), isFalse);
      expect(dio2.options.baseUrl, 'http://y:8000/api/v1');
    });
  });
}

class _InMemoryStorage implements SecureStorage {
  _InMemoryStorage([Map<String, String>? seed])
    : _data = <String, String>{...?seed};
  final Map<String, String> _data;

  @override
  Future<String?> read(String key) async => _data[key];
  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}
