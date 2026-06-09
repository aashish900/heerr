import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/settings.dart';
import 'api_error.dart';

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

/// Builds the app's `Dio` instance from the currently-loaded settings.
/// Depends on `settingsProvider` so the dio rebuilds whenever the user
/// saves a new backend URL or token. Returns a `Future` because settings
/// are loaded asynchronously from secure storage.
@riverpod
Future<Dio> dioClient(DioClientRef ref) async {
  final SettingsValue settings = await ref.watch(settingsProvider.future);

  final Dio dio = Dio(
    BaseOptions(
      baseUrl: settings.backendBaseUrl ?? '',
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      // Don't auto-throw on 4xx/5xx — `apiCall` does typed conversion.
      // We still need dio to flag them as errors so `onError` fires; default
      // `validateStatus` (2xx only) is the right behaviour.
    ),
  );
  dio.interceptors.add(BearerAuthInterceptor(settings.bearerToken));
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
