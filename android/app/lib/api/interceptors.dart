import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Honours the `docs/CONTEXT.md` HTTP-stack promise of "retry-on-503 + logging"
/// (the auth header is `BearerAuthInterceptor` / `SubsonicAuthInterceptor`).
///
/// Two pieces:
///   * [RetryInterceptor] — silently retries transient failures so a single
///     blip doesn't surface a snackbar to the user (DEBT A9).
///   * [DebugLogInterceptor] — request/response tracing, debug builds only.

/// Bounded, backoff-based retry for *transient* dio failures.
///
/// Retries on:
///   * connection / send / receive timeouts and connection errors (the request
///     likely never reached or never completed) — exponential backoff.
///   * HTTP 503 — the backend forwards an upstream rate-limit. Honours
///     `Retry-After` when present, but only retries when the suggested wait is
///     short ([maxRetryAfter]); a long rate-limit is left to surface as a
///     `RateLimitedError` so the user sees the real countdown instead of the
///     app silently hanging.
///
/// All other statuses (401/403/404/422/other 5xx) and Subsonic envelope
/// failures (HTTP 200) flow straight through to `mapDioErrorToApiError`.
///
/// Re-issues via [dio].fetch so the full interceptor chain (auth header) runs
/// again on each attempt. Recursion is bounded by an attempt counter stashed
/// in `RequestOptions.extra`, so a permanently-failing request gives up after
/// [maxRetries] and propagates the final `DioException`.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this.dio,
    this.maxRetries = 2,
    this.backoffBase = const Duration(milliseconds: 500),
    this.maxRetryAfter = const Duration(seconds: 5),
  });

  final Dio dio;

  /// Retries *after* the first attempt. `2` ⇒ up to 3 total attempts.
  final int maxRetries;

  /// Base for exponential backoff on transient network errors: attempt `n`
  /// waits `backoffBase * 2^n` (500ms, then 1s with the default).
  final Duration backoffBase;

  /// Upper bound on a honoured `Retry-After`. Beyond this we don't retry — the
  /// `RateLimitedError` reaches the UI so the user gets the real wait time.
  final Duration maxRetryAfter;

  static const String _attemptKey = 'heerr_retry_attempt';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final RequestOptions req = err.requestOptions;
    final int attempt = (req.extra[_attemptKey] as int?) ?? 0;
    final Duration? delay = _retryDelay(err, attempt);
    if (delay == null) {
      handler.next(err);
      return;
    }

    await Future<void>.delayed(delay);
    req.extra[_attemptKey] = attempt + 1;
    try {
      handler.resolve(await dio.fetch<dynamic>(req));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  /// Delay before the next attempt, or `null` to stop retrying.
  Duration? _retryDelay(DioException err, int attempt) {
    if (attempt >= maxRetries) return null;
    final Duration backoff = backoffBase * (1 << attempt);

    switch (err.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return backoff;
      case DioExceptionType.badResponse:
        if (err.response?.statusCode != 503) return null;
        final Duration? retryAfter = _retryAfter(err.response!.headers);
        if (retryAfter == null) return backoff;
        return retryAfter > maxRetryAfter ? null : retryAfter;
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return null;
    }
  }

  /// Parses `Retry-After` (delta-seconds form). Returns `null` when absent or
  /// unparseable — distinct from `api_error.dart`'s 30s default, because here
  /// "absent" means "fall back to backoff", not "wait 30s".
  Duration? _retryAfter(Headers headers) {
    final String? raw = headers.value('retry-after');
    if (raw == null) return null;
    final int? seconds = int.tryParse(raw);
    return seconds == null ? null : Duration(seconds: seconds);
  }
}

/// Lightweight request/response tracer, active only in debug builds
/// (`kDebugMode`). Writes via `debugPrint` (CLAUDE rule: no `print`) and
/// redacts the bearer token from logged headers.
class DebugLogInterceptor extends Interceptor {
  const DebugLogInterceptor({this.tag = 'dio'});

  final String tag;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      final bool hasAuth = options.headers.containsKey('Authorization');
      debugPrint(
        '[$tag] → ${options.method} ${options.uri}'
        '${hasAuth ? ' (auth: ***)' : ''}',
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (kDebugMode) {
      debugPrint(
        '[$tag] ← ${response.statusCode} ${response.requestOptions.uri}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      final int? status = err.response?.statusCode;
      debugPrint(
        '[$tag] ✗ ${status ?? err.type.name} ${err.requestOptions.uri}',
      );
    }
    handler.next(err);
  }
}
