import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/api/subsonic_client.dart';
import 'package:heerr/providers/secure_storage.dart';

// ---------------------------------------------------------------------------
// Same hand-rolled adapter as test/api/client_test.dart — keeps the test
// surface dep-free (no http_mock_adapter). Records the last request so we
// can assert on query parameters injected by the interceptor.
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

ResponseBody _json(int statusCode, Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      'content-type': <String>['application/json'],
    },
  );
}

/// Subsonic-ok envelope helper. `payload` is merged into the
/// `subsonic-response` object so callers don't have to spell it out.
Map<String, dynamic> _okEnvelope([Map<String, dynamic>? payload]) {
  return <String, dynamic>{
    'subsonic-response': <String, dynamic>{
      'status': 'ok',
      'version': '1.16.1',
      ...?payload,
    },
  };
}

Map<String, dynamic> _failedEnvelope({required int code, String? message}) {
  return <String, dynamic>{
    'subsonic-response': <String, dynamic>{
      'status': 'failed',
      'version': '1.16.1',
      'error': <String, dynamic>{
        'code': code,
        'message': ?message,
      },
    },
  };
}

Dio _dioWith(
  _FakeAdapter adapter, {
  String? username,
  String? password,
  String Function()? salt,
}) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://navi.test'));
  dio.httpClientAdapter = adapter;
  dio.interceptors.add(
    SubsonicAuthInterceptor(
      username: username,
      password: password,
      saltGenerator: salt,
    ),
  );
  return dio;
}

void main() {
  group('SubsonicAuthInterceptor', () {
    test('injects u/s/t/v/c/f when credentials present', () async {
      final _FakeAdapter adapter = _FakeAdapter((_) => _json(200, _okEnvelope()));
      final Dio dio = _dioWith(
        adapter,
        username: 'me',
        password: 'sesame',
        salt: () => 'c19b2d',
      );

      await dio.get<dynamic>('/rest/ping.view');

      final Map<String, dynamic> qp = adapter.lastRequest!.queryParameters;
      expect(qp['u'], 'me');
      expect(qp['s'], 'c19b2d');
      expect(qp['v'], '1.16.1');
      expect(qp['c'], 'heerr');
      expect(qp['f'], 'json');
    });

    test('uses injected salt deterministically for each request', () async {
      int callCount = 0;
      final _FakeAdapter adapter = _FakeAdapter((_) => _json(200, _okEnvelope()));
      final Dio dio = _dioWith(
        adapter,
        username: 'me',
        password: 'x',
        salt: () => 'salt${callCount++}',
      );

      await dio.get<dynamic>('/rest/ping.view');
      expect(adapter.lastRequest!.queryParameters['s'], 'salt0');

      await dio.get<dynamic>('/rest/ping.view');
      expect(adapter.lastRequest!.queryParameters['s'], 'salt1');
    });

    test('t = md5(password + salt) — known Subsonic doc fixture', () async {
      // The Subsonic API docs use this exact example to specify the auth
      // token format:
      //   password = "sesame"
      //   salt     = "c19b2d"
      //   token    = md5("sesamec19b2d") = "26719a1196d2a940705a59634eb18eab"
      final _FakeAdapter adapter = _FakeAdapter((_) => _json(200, _okEnvelope()));
      final Dio dio = _dioWith(
        adapter,
        username: 'me',
        password: 'sesame',
        salt: () => 'c19b2d',
      );

      await dio.get<dynamic>('/rest/ping.view');

      expect(
        adapter.lastRequest!.queryParameters['t'],
        '26719a1196d2a940705a59634eb18eab',
      );
    });

    test('omits auth params when username is null', () async {
      final _FakeAdapter adapter = _FakeAdapter((_) => _json(200, _okEnvelope()));
      final Dio dio = _dioWith(
        adapter,
        password: 'pw',
        salt: () => 'salt',
      );

      await dio.get<dynamic>('/rest/ping.view');

      final Map<String, dynamic> qp = adapter.lastRequest!.queryParameters;
      expect(qp.containsKey('u'), isFalse);
      expect(qp.containsKey('t'), isFalse);
      expect(qp.containsKey('s'), isFalse);
    });

    test('omits auth params when password is null', () async {
      final _FakeAdapter adapter = _FakeAdapter((_) => _json(200, _okEnvelope()));
      final Dio dio = _dioWith(
        adapter,
        username: 'me',
        salt: () => 'salt',
      );

      await dio.get<dynamic>('/rest/ping.view');

      expect(adapter.lastRequest!.queryParameters.containsKey('t'), isFalse);
    });

    test('omits auth params when either credential is empty string', () async {
      final _FakeAdapter adapter = _FakeAdapter((_) => _json(200, _okEnvelope()));
      final Dio dio = _dioWith(
        adapter,
        username: '',
        password: 'pw',
        salt: () => 'salt',
      );

      await dio.get<dynamic>('/rest/ping.view');

      expect(adapter.lastRequest!.queryParameters.containsKey('u'), isFalse);
    });

    test('preserves caller-supplied query params (e.g. id=) alongside auth', () async {
      final _FakeAdapter adapter = _FakeAdapter((_) => _json(200, _okEnvelope()));
      final Dio dio = _dioWith(
        adapter,
        username: 'me',
        password: 'x',
        salt: () => 'salt',
      );

      await dio.get<dynamic>(
        '/rest/getAlbum.view',
        queryParameters: <String, dynamic>{'id': 'abc-123'},
      );

      final Map<String, dynamic> qp = adapter.lastRequest!.queryParameters;
      expect(qp['id'], 'abc-123');
      expect(qp['u'], 'me');
    });
  });

  group('subsonicCall — happy path', () {
    test('returns the parsed envelope on status:ok', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json(200, _okEnvelope(<String, dynamic>{'pingedAt': 42})),
      );
      final Dio dio = _dioWith(
        adapter,
        username: 'me',
        password: 'x',
        salt: () => 'salt',
      );

      final Map<String, dynamic> env = await subsonicCall<Map<String, dynamic>>(
        () => dio.get<dynamic>('/rest/ping.view'),
        (Map<String, dynamic> env) => env,
      );

      expect(env['status'], 'ok');
      expect(env['pingedAt'], 42);
    });
  });

  group('subsonicCall — error envelope mapping', () {
    test('code 40 → UnauthorizedError with detail message', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json(
          200,
          _failedEnvelope(code: 40, message: 'Wrong username or password.'),
        ),
      );
      final Dio dio = _dioWith(
        adapter,
        username: 'me',
        password: 'bad',
        salt: () => 'salt',
      );

      await expectLater(
        subsonicCall<dynamic>(
          () => dio.get<dynamic>('/rest/ping.view'),
          (Map<String, dynamic> e) => e,
        ),
        throwsA(
          isA<UnauthorizedError>().having(
            (UnauthorizedError e) => e.detail,
            'detail',
            'Wrong username or password.',
          ),
        ),
      );
    });

    test('code 41 → UnauthorizedError (LDAP token-auth refusal)', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json(200, _failedEnvelope(code: 41, message: 'LDAP')),
      );
      final Dio dio = _dioWith(
        adapter,
        username: 'me',
        password: 'x',
        salt: () => 'salt',
      );

      await expectLater(
        subsonicCall<dynamic>(
          () => dio.get<dynamic>('/rest/ping.view'),
          (Map<String, dynamic> e) => e,
        ),
        throwsA(isA<UnauthorizedError>()),
      );
    });

    test('code 50 → ForbiddenError', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json(
          200,
          _failedEnvelope(code: 50, message: 'User not authorized.'),
        ),
      );
      final Dio dio = _dioWith(
        adapter,
        username: 'me',
        password: 'x',
        salt: () => 'salt',
      );

      await expectLater(
        subsonicCall<dynamic>(
          () => dio.get<dynamic>('/rest/getAlbum.view'),
          (Map<String, dynamic> e) => e,
        ),
        throwsA(
          isA<ForbiddenError>().having(
            (ForbiddenError e) => e.detail,
            'detail',
            'User not authorized.',
          ),
        ),
      );
    });

    test('code 70 → NotFoundError', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json(
          200,
          _failedEnvelope(code: 70, message: 'Album not found.'),
        ),
      );
      final Dio dio = _dioWith(
        adapter,
        username: 'me',
        password: 'x',
        salt: () => 'salt',
      );

      await expectLater(
        subsonicCall<dynamic>(
          () => dio.get<dynamic>('/rest/getAlbum.view'),
          (Map<String, dynamic> e) => e,
        ),
        throwsA(
          isA<NotFoundError>().having(
            (NotFoundError e) => e.detail,
            'detail',
            'Album not found.',
          ),
        ),
      );
    });

    test('unknown code (e.g. 10) → HttpStatusError carrying that code', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json(
          200,
          _failedEnvelope(code: 10, message: 'Required parameter missing.'),
        ),
      );
      final Dio dio = _dioWith(
        adapter,
        username: 'me',
        password: 'x',
        salt: () => 'salt',
      );

      await expectLater(
        subsonicCall<dynamic>(
          () => dio.get<dynamic>('/rest/search3.view'),
          (Map<String, dynamic> e) => e,
        ),
        throwsA(
          isA<HttpStatusError>().having(
            (HttpStatusError e) => e.statusCode,
            'statusCode',
            10,
          ),
        ),
      );
    });

    test('failed envelope without error block → HttpStatusError(0)', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json(200, <String, dynamic>{
          'subsonic-response': <String, dynamic>{
            'status': 'failed',
            'version': '1.16.1',
          },
        }),
      );
      final Dio dio = _dioWith(
        adapter,
        username: 'me',
        password: 'x',
        salt: () => 'salt',
      );

      await expectLater(
        subsonicCall<dynamic>(
          () => dio.get<dynamic>('/rest/ping.view'),
          (Map<String, dynamic> e) => e,
        ),
        throwsA(isA<HttpStatusError>()),
      );
    });
  });

  group('subsonicCall — transport errors', () {
    test('connection error → NetworkError', () async {
      final Dio dio = Dio(BaseOptions(baseUrl: 'http://navi.test'));
      dio.httpClientAdapter = _FakeAdapter((RequestOptions opts) {
        throw DioException(
          requestOptions: opts,
          type: DioExceptionType.connectionError,
          error: 'no route to host',
        );
      });

      await expectLater(
        subsonicCall<dynamic>(
          () => dio.get<dynamic>('/rest/ping.view'),
          (Map<String, dynamic> e) => e,
        ),
        throwsA(isA<NetworkError>()),
      );
    });

    test('HTTP 500 → HttpStatusError(500)', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json(500, <String, dynamic>{'detail': 'boom'}),
      );
      final Dio dio = _dioWith(
        adapter,
        username: 'me',
        password: 'x',
        salt: () => 'salt',
      );

      await expectLater(
        subsonicCall<dynamic>(
          () => dio.get<dynamic>('/rest/ping.view'),
          (Map<String, dynamic> e) => e,
        ),
        throwsA(
          isA<HttpStatusError>().having(
            (HttpStatusError e) => e.statusCode,
            'statusCode',
            500,
          ),
        ),
      );
    });
  });

  group('subsonicDioClientProvider', () {
    test('builds dio with navidromeBaseUrl + credentials from settings', () async {
      final _InMemoryStorage store = _InMemoryStorage(<String, String>{
        'backend_base_url': 'http://x:8000/api/v1',
        'bearer_token': 'tok',
        'navidrome_base_url': 'http://navi:4533',
        'navidrome_username': 'me',
        'navidrome_password': 'pw',
      });
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          secureStorageProvider.overrideWith((Ref<SecureStorage> ref) => store),
        ],
      );
      addTearDown(c.dispose);

      final Dio dio = await c.read(subsonicDioClientProvider.future);

      expect(dio.options.baseUrl, 'http://navi:4533');
      final SubsonicAuthInterceptor interceptor =
          dio.interceptors.whereType<SubsonicAuthInterceptor>().single;
      expect(interceptor.username, 'me');
      expect(interceptor.password, 'pw');
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
