import 'package:dio/dio.dart';

import 'api_error.dart';
import 'backend_profile.dart';
import 'endpoints.dart';

/// Successful response from `POST /auth/login` (backend J6).
///
/// The backend forwards the [token] minted by its CLI-equivalent path
/// when the supplied creds passed against Navidrome. [scopes] mirror the
/// existing bearer-token scope strings (`read`, `download`). [navidromeUrl]
/// + [navidromeUsername] are echoed back so the device can build the
/// `Profile` without having to ask the user to paste a third URL — the
/// backend already knows where its sibling Navidrome lives.
class AuthLoginResponse {
  const AuthLoginResponse({
    required this.token,
    required this.scopes,
    required this.navidromeUrl,
    required this.navidromeUsername,
    required this.profile,
  });

  final String token;
  final List<String> scopes;
  final String navidromeUrl;
  final String navidromeUsername;
  final BackendProfileData profile;

  factory AuthLoginResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawScopes =
        (json['scopes'] as List<dynamic>? ?? const <dynamic>[]);
    return AuthLoginResponse(
      token: json['token'] as String,
      scopes:
          rawScopes.map((dynamic s) => s.toString()).toList(growable: false),
      navidromeUrl: json['navidrome_url'] as String,
      navidromeUsername: json['navidrome_username'] as String,
      profile: BackendProfileData.fromJson(
          (json['profile'] as Map<String, dynamic>?) ?? <String, dynamic>{}),
    );
  }
}

/// One-shot login call. Constructs its own [Dio] (no auth interceptor —
/// login is the only call without a bearer token) so the caller doesn't
/// have to manage a half-configured client.
///
/// [baseUrl] is the heerr backend's root (e.g. `http://100.x.y.z:8000/api/v1`).
/// On failure, throws an [ApiError] from the standard mapping —
/// `UnauthorizedError` for bad creds, `RateLimitedError` (HTTP 503) for
/// "Navidrome unreachable" per the backend J6 contract.
Future<AuthLoginResponse> authLogin({
  required String baseUrl,
  required String username,
  required String password,
  Dio? dio,
}) async {
  final Dio client = dio ??
      Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

  try {
    final Response<dynamic> res = await client.post<dynamic>(
      Endpoints.authLogin,
      data: <String, Object?>{
        'username': username,
        'password': password,
      },
    );
    final Map<String, dynamic> data = res.data as Map<String, dynamic>;
    return AuthLoginResponse.fromJson(data);
  } on DioException catch (e) {
    throw mapDioErrorToApiError(e);
  }
}
