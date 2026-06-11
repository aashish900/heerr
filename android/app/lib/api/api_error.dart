import 'package:dio/dio.dart';

/// Typed error envelope for every backend response. UI code switches on this
/// (Dart sealed classes give exhaustive switches) instead of inspecting raw
/// `DioException`s. Each variant maps to a row in `docs/PLAN.md` §9 (Error UX).
sealed class ApiError implements Exception {
  const ApiError({required this.detail});

  /// The `detail` string from the FastAPI error envelope, when present.
  final String? detail;

  /// Short, user-facing message used as a fallback when the UI doesn't
  /// customise the snackbar copy. Avoid surfacing the raw exception type.
  String get message;

  @override
  String toString() => '$runtimeType($message)';
}

/// 401 — token missing / unknown / revoked. UI: snackbar "auth failed" +
/// redirect to /settings (per PLAN §9).
final class UnauthorizedError extends ApiError {
  const UnauthorizedError({super.detail});
  @override
  String get message => detail ?? 'auth failed — re-paste your token';
}

/// 403 — token lacks the required scope (read / download) or is non-admin
/// hitting `/admin/*`. UI: snackbar with the action that was denied.
final class ForbiddenError extends ApiError {
  const ForbiddenError({super.detail});
  @override
  String get message => detail ?? 'insufficient scope';
}

/// 422 — request body / param invalid. UI: inline form error if it was
/// user-entered, snackbar otherwise.
final class UnprocessableError extends ApiError {
  const UnprocessableError({super.detail});
  @override
  String get message => detail ?? 'invalid request';
}

/// 503 — upstream Spotify rate-limit. Backend forwards `Retry-After` from
/// Spotify; we parse it for the retry banner.
final class RateLimitedError extends ApiError {
  const RateLimitedError({required this.retryAfter, super.detail});
  final Duration retryAfter;
  @override
  String get message =>
      detail ?? 'Spotify rate-limited — retry in ${retryAfter.inSeconds}s';
}

/// Network failure — DNS, TCP, TLS, timeout, etc. UI: snackbar "can't reach
/// backend — check Tailscale".
final class NetworkError extends ApiError {
  const NetworkError({this.cause}) : super(detail: null);
  final Object? cause;
  @override
  String get message => 'cannot reach backend — check tailscale';
}

/// 404 / Subsonic code 70 — requested entity (artist / album / playlist /
/// stream) does not exist. UI: snackbar with the detail message.
final class NotFoundError extends ApiError {
  const NotFoundError({super.detail});
  @override
  String get message => detail ?? 'not found';
}

/// Catch-all for any other 4xx/5xx. UI: snackbar with the status + detail.
final class HttpStatusError extends ApiError {
  const HttpStatusError({required this.statusCode, super.detail});
  final int statusCode;
  @override
  String get message => '$statusCode: ${detail ?? "request failed"}';
}

// ---------------------------------------------------------------------------
// Mapping: DioException → ApiError. Pure function; no I/O, easy to unit-test.
// ---------------------------------------------------------------------------

ApiError mapDioErrorToApiError(DioException e) {
  // Connection-level failures: type tells us before there's a response.
  switch (e.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return NetworkError(cause: e.error);
    case DioExceptionType.badResponse:
    case DioExceptionType.cancel:
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      break;
  }

  final Response<dynamic>? res = e.response;
  if (res == null) {
    return NetworkError(cause: e.error);
  }

  final String? detail = _extractDetail(res.data);

  switch (res.statusCode) {
    case 401:
      return UnauthorizedError(detail: detail);
    case 403:
      return ForbiddenError(detail: detail);
    case 404:
      return NotFoundError(detail: detail);
    case 422:
      return UnprocessableError(detail: detail);
    case 503:
      return RateLimitedError(
        retryAfter: _parseRetryAfter(res.headers),
        detail: detail,
      );
    default:
      return HttpStatusError(
        statusCode: res.statusCode ?? 0,
        detail: detail,
      );
  }
}

/// FastAPI error envelope is `{"detail": "..."}` or `{"detail": [...]}` (the
/// list form is the Pydantic validation case). Only return a string when we
/// can.
String? _extractDetail(dynamic data) {
  if (data is Map<String, dynamic>) {
    final dynamic d = data['detail'];
    if (d is String) return d;
    if (d is List && d.isNotEmpty) return d.first.toString();
  }
  return null;
}

Duration _parseRetryAfter(Headers headers) {
  final String? raw = headers.value('retry-after');
  if (raw == null) return const Duration(seconds: 30);
  final int? seconds = int.tryParse(raw);
  if (seconds != null) return Duration(seconds: seconds);
  // HTTP-date form is rarely used by FastAPI; default if we can't parse.
  return const Duration(seconds: 30);
}
