import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/api/client.dart';
import 'package:heerr/api/interceptors.dart';

// ---------------------------------------------------------------------------
// Adapter that plays back a scripted sequence of responses, one per attempt,
// and counts how many times the request was actually issued. The last entry
// repeats if the request is retried beyond the script length.
// ---------------------------------------------------------------------------
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.script);

  final List<FutureOr<ResponseBody> Function(RequestOptions options)> script;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    final int i = calls < script.length ? calls : script.length - 1;
    calls++;
    return script[i](options);
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

FutureOr<ResponseBody> Function(RequestOptions) _connectionError() {
  return (RequestOptions opts) {
    throw DioException(
      requestOptions: opts,
      type: DioExceptionType.connectionError,
      error: 'no route to host',
    );
  };
}

// Zero backoff keeps the tests instant; maxRetryAfter default 5s matches prod.
Dio _dioWithRetry(
  _ScriptedAdapter adapter, {
  int maxRetries = 2,
  Duration maxRetryAfter = const Duration(seconds: 5),
}) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
  dio.httpClientAdapter = adapter;
  dio.interceptors.add(
    RetryInterceptor(
      dio: dio,
      maxRetries: maxRetries,
      backoffBase: Duration.zero,
      maxRetryAfter: maxRetryAfter,
    ),
  );
  return dio;
}

Future<dynamic> _get(Dio dio) =>
    apiCall<dynamic>(() => dio.get<dynamic>('/queue'), (dynamic d) => d);

void main() {
  group('RetryInterceptor — transient retries', () {
    test('503 then 200 → succeeds after one retry', () async {
      final _ScriptedAdapter adapter = _ScriptedAdapter(<
        FutureOr<ResponseBody> Function(RequestOptions)
      >[
        (_) => _json(503, <String, dynamic>{'detail': 'rate limited'}),
        (_) => _json(200, <String, dynamic>{'status': 'ok'}),
      ]);
      final Dio dio = _dioWithRetry(adapter);

      final dynamic result = await _get(dio);

      expect(result, <String, dynamic>{'status': 'ok'});
      expect(adapter.calls, 2);
    });

    test('connection error then 200 → succeeds after one retry', () async {
      final _ScriptedAdapter adapter = _ScriptedAdapter(<
        FutureOr<ResponseBody> Function(RequestOptions)
      >[
        _connectionError(),
        (_) => _json(200, <String, dynamic>{'status': 'ok'}),
      ]);
      final Dio dio = _dioWithRetry(adapter);

      final dynamic result = await _get(dio);

      expect(result, <String, dynamic>{'status': 'ok'});
      expect(adapter.calls, 2);
    });

    test('persistent 503 → gives up after maxRetries, surfaces '
        'RateLimitedError', () async {
      final _ScriptedAdapter adapter = _ScriptedAdapter(<
        FutureOr<ResponseBody> Function(RequestOptions)
      >[
        (_) => _json(503, <String, dynamic>{'detail': 'rate limited'}),
      ]);
      final Dio dio = _dioWithRetry(adapter, maxRetries: 2);

      await expectLater(_get(dio), throwsA(isA<RateLimitedError>()));
      // 1 initial + 2 retries = 3 attempts.
      expect(adapter.calls, 3);
    });

    test('persistent connection error → gives up, surfaces NetworkError',
        () async {
      final _ScriptedAdapter adapter = _ScriptedAdapter(<
        FutureOr<ResponseBody> Function(RequestOptions)
      >[
        _connectionError(),
      ]);
      final Dio dio = _dioWithRetry(adapter, maxRetries: 1);

      await expectLater(_get(dio), throwsA(isA<NetworkError>()));
      expect(adapter.calls, 2);
    });
  });

  group('RetryInterceptor — Retry-After policy', () {
    test('short Retry-After is honoured and retried', () async {
      final _ScriptedAdapter adapter = _ScriptedAdapter(<
        FutureOr<ResponseBody> Function(RequestOptions)
      >[
        (_) => _json(
              503,
              <String, dynamic>{'detail': 'rate limited'},
              headers: <String, List<String>>{
                'retry-after': <String>['0'],
              },
            ),
        (_) => _json(200, <String, dynamic>{'status': 'ok'}),
      ]);
      final Dio dio = _dioWithRetry(adapter);

      final dynamic result = await _get(dio);

      expect(result, <String, dynamic>{'status': 'ok'});
      expect(adapter.calls, 2);
    });

    test('long Retry-After exceeds cap → no retry, surfaces immediately',
        () async {
      final _ScriptedAdapter adapter = _ScriptedAdapter(<
        FutureOr<ResponseBody> Function(RequestOptions)
      >[
        (_) => _json(
              503,
              <String, dynamic>{'detail': 'rate limited'},
              headers: <String, List<String>>{
                'retry-after': <String>['60'],
              },
            ),
      ]);
      final Dio dio =
          _dioWithRetry(adapter, maxRetryAfter: const Duration(seconds: 5));

      await expectLater(
        _get(dio),
        throwsA(
          isA<RateLimitedError>().having(
            (RateLimitedError e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 60),
          ),
        ),
      );
      expect(adapter.calls, 1);
    });
  });

  group('RetryInterceptor — non-retryable', () {
    test('401 is not retried', () async {
      final _ScriptedAdapter adapter = _ScriptedAdapter(<
        FutureOr<ResponseBody> Function(RequestOptions)
      >[
        (_) => _json(401, <String, dynamic>{'detail': 'bad token'}),
      ]);
      final Dio dio = _dioWithRetry(adapter);

      await expectLater(_get(dio), throwsA(isA<UnauthorizedError>()));
      expect(adapter.calls, 1);
    });

    test('500 (non-503) is not retried', () async {
      final _ScriptedAdapter adapter = _ScriptedAdapter(<
        FutureOr<ResponseBody> Function(RequestOptions)
      >[
        (_) => _json(500, <String, dynamic>{'detail': 'boom'}),
      ]);
      final Dio dio = _dioWithRetry(adapter);

      await expectLater(_get(dio), throwsA(isA<HttpStatusError>()));
      expect(adapter.calls, 1);
    });
  });
}
