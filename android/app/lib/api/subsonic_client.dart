import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/profile.dart';
import '../providers/profiles/active_profile.dart';
import 'api_error.dart';
import 'interceptors.dart';

part 'subsonic_client.g.dart';

/// Subsonic API version this client implements. Navidrome supports 1.16.1
/// and accepts older clients; pinning here makes the version we send
/// explicit + testable.
const String _subsonicApiVersion = '1.16.1';

/// `c=` client identifier. Navidrome logs this; useful for distinguishing
/// the heerr Android client from a generic Subsonic browser.
const String _subsonicClientName = 'heerr';

/// Injects the standard Subsonic auth query params on every outbound request:
///   `u=<username>`
///   `s=<random hex salt, regenerated per request>`
///   `t=md5(password + salt)`
///   `v=1.16.1`
///   `c=heerr`
///   `f=json`
///
/// When username or password is null/empty the interceptor is a no-op — the
/// request goes out unauthenticated and Navidrome returns a Subsonic 40
/// error envelope (mapped to [UnauthorizedError] by [subsonicCall]).
///
/// [saltGenerator] is injectable for deterministic unit tests; production
/// callers should pass nothing and let the default cryptographically-strong
/// generator fire.
///
/// A3: username + password are resolved **per request** via
/// [usernameResolver] / [passwordResolver] rather than captured by value at
/// construction, so a Navidrome credential change on the active profile does
/// not require rebuilding the whole `Dio`. The dio only rebuilds when the
/// Navidrome *base URL* changes (see [subsonicDioClient]).
class SubsonicAuthInterceptor extends Interceptor {
  SubsonicAuthInterceptor({
    required this.usernameResolver,
    required this.passwordResolver,
    String Function()? saltGenerator,
  }) : _saltGenerator = saltGenerator ?? _randomHexSalt;

  /// Returns the current Navidrome username; called on every `onRequest`.
  final String? Function() usernameResolver;

  /// Returns the current Navidrome password; called on every `onRequest`.
  final String? Function() passwordResolver;

  final String Function() _saltGenerator;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final String? u = usernameResolver();
    final String? p = passwordResolver();
    if (u != null && u.isNotEmpty && p != null && p.isNotEmpty) {
      final String salt = _saltGenerator();
      final String token =
          md5.convert(utf8.encode(p + salt)).toString();
      options.queryParameters = <String, dynamic>{
        ...options.queryParameters,
        'u': u,
        's': salt,
        't': token,
        'v': _subsonicApiVersion,
        'c': _subsonicClientName,
        'f': 'json',
      };
    }
    handler.next(options);
  }
}

/// Default salt generator: 6 cryptographically-random bytes, hex-encoded.
/// (12 hex chars; Subsonic clients in the wild use 6-byte salts.)
String _randomHexSalt() {
  final Random rng = Random.secure();
  final List<int> bytes =
      List<int>.generate(6, (_) => rng.nextInt(256));
  return bytes
      .map((int b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}

/// Process-lifetime salt for the read-only URL builders (cover art + stream).
///
/// A11: Subsonic accepts a stable salt within a session, and the salt is
/// independent of the password (the token recomputes as `md5(password+salt)`,
/// so a profile switch with a new password still produces a valid token from
/// the same salt). Reusing one salt for the lifetime of the process keeps the
/// generated URL identical across renders of the same `coverArtId`+`size`,
/// which lets Flutter's URL-keyed image cache actually hit instead of cold-
/// fetching every tile on every scroll. State-mutating / API calls keep
/// rotating the salt per request via [SubsonicAuthInterceptor].
String? _sessionSalt;
String sessionStableSalt() => _sessionSalt ??= _randomHexSalt();

/// Build a `getCoverArt.view` URL with Subsonic auth params embedded as
/// query string. Needed because Flutter's `Image.network` does not flow
/// through the dio interceptor — the auth params have to be baked into the
/// URL the framework fetches directly.
///
/// [saltGenerator] is injectable for deterministic tests; production callers
/// pass nothing and let the [sessionStableSalt] default fire.
///
/// A11: the default salt is **session-stable**, so repeated calls for the same
/// `coverArtId`+`size` return an identical URL — Flutter's URL-keyed image
/// cache hits instead of cold-fetching every tile on every scroll.
String buildSubsonicCoverArtUrl({
  required String baseUrl,
  required String username,
  required String password,
  required String coverArtId,
  int? size,
  String Function()? saltGenerator,
}) {
  final String salt = (saltGenerator ?? sessionStableSalt)();
  final String token =
      md5.convert(utf8.encode(password + salt)).toString();
  final Map<String, String> params = <String, String>{
    'id': coverArtId,
    if (size != null) 'size': size.toString(),
    'u': username,
    's': salt,
    't': token,
    'v': _subsonicApiVersion,
    'c': _subsonicClientName,
  };
  return Uri.parse(baseUrl)
      .replace(
        path: '/rest/getCoverArt.view',
        queryParameters: params,
      )
      .toString();
}

/// Build a `stream.view` URL for an audio file by song id, with Subsonic
/// auth params embedded as query string. Needed because the audio player
/// (just_audio) fetches the stream URL directly via HTTP range requests —
/// it doesn't flow through the dio interceptor, so auth has to live in the
/// URL the framework opens.
///
/// A11: like [buildSubsonicCoverArtUrl] this defaults to [sessionStableSalt],
/// so a stream URL is stable across renders. Not strictly required for audio
/// (each track is opened once per playback), but keeps both read-only URL
/// builders on the same policy.
String buildSubsonicStreamUrl({
  required String baseUrl,
  required String username,
  required String password,
  required String songId,
  String Function()? saltGenerator,
}) {
  final String salt = (saltGenerator ?? sessionStableSalt)();
  final String token =
      md5.convert(utf8.encode(password + salt)).toString();
  final Map<String, String> params = <String, String>{
    'id': songId,
    'u': username,
    's': salt,
    't': token,
    'v': _subsonicApiVersion,
    'c': _subsonicClientName,
  };
  return Uri.parse(baseUrl)
      .replace(
        path: '/rest/stream.view',
        queryParameters: params,
      )
      .toString();
}

/// Builds a `Dio` for Subsonic calls against the active [Profile]'s
/// Navidrome base URL. Depends on [activeProfileProvider] so a profile
/// switch invalidates and rebuilds with the new auth.
@riverpod
Future<Dio> subsonicDioClient(SubsonicDioClientRef ref) async {
  // A1: the active Profile is the single source of Navidrome credentials.
  // The pre-S legacy single-set keys are gone.
  //
  // A3: watch only the Navidrome *base URL* (via `select`) so a credential
  // change on the same server doesn't rebuild the dio — username/password are
  // resolved per request inside the interceptor via `ref.read` below.
  final String baseUrl = ref.watch(
        activeProfileProvider.select((Profile? p) => p?.navidromeBaseUrl),
      ) ??
      '';

  final Dio dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
  // Order mirrors the heerr dio (see `client.dart`): auth params, then retry on
  // transient transport failures, then debug logging last. Subsonic envelope
  // failures arrive as HTTP 200 and are handled by `subsonicCall`, not here —
  // the retry only fires on real transport 5xx / network errors.
  dio.interceptors.add(
    SubsonicAuthInterceptor(
      usernameResolver: () =>
          ref.read(activeProfileProvider)?.navidromeUsername,
      passwordResolver: () =>
          ref.read(activeProfileProvider)?.navidromePassword,
    ),
  );
  dio.interceptors.add(RetryInterceptor(dio: dio));
  dio.interceptors.add(const DebugLogInterceptor(tag: 'subsonic'));
  return dio;
}

/// Wrap a Subsonic dio call, parse the standard envelope, and translate
/// failures into the shared [ApiError] hierarchy.
///
/// Every Subsonic response is wrapped as:
/// ```
/// {
///   "subsonic-response": {
///     "status": "ok" | "failed",
///     "version": "1.16.1",
///     ...payload (when ok)...
///     "error": { "code": N, "message": "..." }   (when failed)
///   }
/// }
/// ```
///
/// Note: Subsonic returns HTTP 200 even on semantic failures (e.g. wrong
/// password) — the failure is inside the envelope. [subsonicCall] inspects
/// the envelope and throws the matching [ApiError]. Transport-level
/// failures (network, 5xx) still go through [mapDioErrorToApiError].
///
/// [parse] receives the envelope map (everything under `subsonic-response`)
/// so callers can pick their payload key — e.g. `(env) => env['album']`.
Future<T> subsonicCall<T>(
  Future<Response<dynamic>> Function() request,
  T Function(Map<String, dynamic> envelope) parse,
) async {
  final Response<dynamic> res;
  try {
    res = await request();
  } on DioException catch (e) {
    throw mapDioErrorToApiError(e);
  }

  final dynamic body = res.data;
  if (body is! Map<String, dynamic>) {
    throw const HttpStatusError(
      statusCode: 0,
      detail: 'invalid subsonic response envelope',
    );
  }
  final dynamic envelope = body['subsonic-response'];
  if (envelope is! Map<String, dynamic>) {
    throw const HttpStatusError(
      statusCode: 0,
      detail: 'missing subsonic-response envelope',
    );
  }

  if (envelope['status'] == 'failed') {
    final dynamic err = envelope['error'];
    if (err is Map<String, dynamic>) {
      throw mapSubsonicErrorToApiError(
        (err['code'] as num?)?.toInt() ?? 0,
        err['message'] as String?,
      );
    }
    throw const HttpStatusError(
      statusCode: 0,
      detail: 'subsonic failed without error block',
    );
  }

  return parse(envelope);
}

/// Map a Subsonic error code (per the Subsonic API docs) to an [ApiError]
/// variant. Subsonic-specific variants exist for auth (40/41) and the
/// generic server-error case so the snackbar copy can point the user to
/// the Navidrome creds rather than the heerr bearer token.
///
/// References:
/// - 40: Wrong username or password.
/// - 41: Token authentication not supported for LDAP users.
/// - 50: User is not authorized for the given operation.
/// - 70: The requested data was not found.
ApiError mapSubsonicErrorToApiError(int code, String? message) {
  switch (code) {
    case 40:
    case 41:
      return NavidromeAuthError(detail: message);
    case 50:
      return ForbiddenError(detail: message);
    case 70:
      return NotFoundError(detail: message);
    default:
      return NavidromeServerError(code: code, detail: message);
  }
}
