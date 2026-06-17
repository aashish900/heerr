import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/api/auth_login.dart';

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

Dio _dioWith(_FakeAdapter adapter) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('authLogin', () {
    test('happy path — parses token + scopes + navidrome echo', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json(200, <String, dynamic>{
          'token': 'tok-from-backend',
          'scopes': <String>['read', 'download'],
          'navidrome_url': 'http://100.64.0.1:4533',
          'navidrome_username': 'alice',
        }),
      );
      final Dio dio = _dioWith(adapter);

      final AuthLoginResponse res = await authLogin(
        baseUrl: 'http://test/api/v1',
        username: 'alice',
        password: 'hunter2',
        dio: dio,
      );

      expect(adapter.lastRequest!.method, 'POST');
      expect(adapter.lastRequest!.path, '/auth/login');
      final Map<String, dynamic> sentBody =
          adapter.lastRequest!.data as Map<String, dynamic>;
      expect(sentBody, <String, dynamic>{
        'username': 'alice',
        'password': 'hunter2',
      });

      expect(res.token, 'tok-from-backend');
      expect(res.scopes, <String>['read', 'download']);
      expect(res.navidromeUrl, 'http://100.64.0.1:4533');
      expect(res.navidromeUsername, 'alice');
    });

    test('401 → UnauthorizedError (bad creds)', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json(401, <String, dynamic>{
          'detail': 'invalid Navidrome credentials',
        }),
      );
      final Dio dio = _dioWith(adapter);

      await expectLater(
        () => authLogin(
          baseUrl: 'http://test/api/v1',
          username: 'alice',
          password: 'wrong',
          dio: dio,
        ),
        throwsA(isA<UnauthorizedError>()),
      );
    });

    test('503 → RateLimitedError (Navidrome unreachable per J6 contract)',
        () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json(503, <String, dynamic>{
          'detail': 'Navidrome unreachable',
        }),
      );
      final Dio dio = _dioWith(adapter);

      await expectLater(
        () => authLogin(
          baseUrl: 'http://test/api/v1',
          username: 'alice',
          password: 'hunter2',
          dio: dio,
        ),
        throwsA(isA<RateLimitedError>()),
      );
    });

    test('connection failure → NetworkError', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (RequestOptions options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const FakeSocketException('connection refused'),
        ),
      );
      final Dio dio = _dioWith(adapter);

      await expectLater(
        () => authLogin(
          baseUrl: 'http://test/api/v1',
          username: 'alice',
          password: 'hunter2',
          dio: dio,
        ),
        throwsA(isA<NetworkError>()),
      );
    });

    test('500 → HttpStatusError (catch-all)', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _json(500, <String, dynamic>{'detail': 'kaboom'}),
      );
      final Dio dio = _dioWith(adapter);

      await expectLater(
        () => authLogin(
          baseUrl: 'http://test/api/v1',
          username: 'alice',
          password: 'hunter2',
          dio: dio,
        ),
        throwsA(isA<HttpStatusError>()),
      );
    });
  });
}

// Tiny placeholder error type to feed DioException.error — keeps the test
// file free of dart:io imports while still exercising the connection-error
// path in mapDioErrorToApiError.
class FakeSocketException implements Exception {
  const FakeSocketException(this.message);
  final String message;
  @override
  String toString() => 'FakeSocketException: $message';
}
