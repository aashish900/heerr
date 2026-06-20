import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/profile.dart';
import '../providers/profiles/active_profile.dart';
import 'api_error.dart';
import 'interceptors.dart';

part 'client.g.dart';

/// Injects `Authorization: Bearer <token>` on every outbound request when a
/// token is configured. No header is added when the token is null/empty so
/// the auth-failure path (401 → redirect to settings) stays uniform between
/// "token not set yet" and "token rejected by server".
class BearerAuthInterceptor extends Interceptor {
  BearerAuthInterceptor(this.token);
  final String? token;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final String? t = token;
    if (t != null && t.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $t';
    }
    handler.next(options);
  }
}

/// Builds the app's `Dio` instance from the active [Profile]. Depends on
/// `activeProfileProvider` so the dio rebuilds whenever the active profile
/// (and therefore the backend URL / bearer token) changes. Returns a
/// `Future` so the large set of existing `.future` call sites are unchanged.
@riverpod
Future<Dio> dioClient(DioClientRef ref) async {
  // A1: the active Profile is the single source of credentials. The pre-S
  // legacy single-set keys are gone — `migrateLegacyCreds` (S3) runs before
  // the first `runApp`, and a null active profile means the router redirect
  // (S5) has already sent the user to /login.
  final Profile? active = ref.watch(activeProfileProvider);
  final String baseUrl = active?.heerrBaseUrl ?? '';
  final String? token = active?.heerrBearerToken;

  final Dio dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      // Don't auto-throw on 4xx/5xx — `apiCall` does typed conversion.
      // We still need dio to flag them as errors so `onError` fires; default
      // `validateStatus` (2xx only) is the right behaviour.
    ),
  );
  // Order: auth header first, then retry (re-issues through the whole chain on
  // transient 503 / network blips), then logging last so it traces the final
  // outcome. See `interceptors.dart` for the retry/backoff policy.
  dio.interceptors.add(BearerAuthInterceptor(token));
  dio.interceptors.add(RetryInterceptor(dio: dio));
  dio.interceptors.add(const DebugLogInterceptor(tag: 'heerr'));
  return dio;
}

/// Wrap a dio call so failures surface as the typed [ApiError] hierarchy
/// (sealed → exhaustive switching in the UI). [parse] is invoked only on
/// success (2xx) with the decoded response body.
Future<T> apiCall<T>(
  Future<Response<dynamic>> Function() request,
  T Function(dynamic data) parse,
) async {
  try {
    final Response<dynamic> res = await request();
    return parse(res.data);
  } on DioException catch (e) {
    throw mapDioErrorToApiError(e);
  }
}
