import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_error.dart';
import '../router.dart';

/// Build the `SnackBar` for a typed [ApiError] per PLAN.md §9. Pure
/// function so it's easy to unit-test — `showApiError` wraps this with the
/// side-effects (snackbar display + 401 redirect).
///
/// [action] is the verb the user attempted ("search", "download") and
/// surfaces in the 403 copy.
SnackBar buildApiErrorSnackBar(ApiError error, {String? action}) {
  return switch (error) {
    UnauthorizedError() => const SnackBar(
        content: Text('auth failed — re-paste your token'),
      ),
    ForbiddenError() => SnackBar(
        content: Text(
          action != null
              ? 'this token cannot $action'
              : (error.detail ?? 'insufficient scope'),
        ),
      ),
    UnprocessableError(detail: final String? detail) => SnackBar(
        content: Text(detail ?? 'invalid request'),
      ),
    RateLimitedError(retryAfter: final Duration retryAfter) => SnackBar(
        content:
            Text('Spotify rate-limited — retry in ${retryAfter.inSeconds}s'),
        duration: Duration(seconds: retryAfter.inSeconds.clamp(2, 10)),
      ),
    NetworkError() => const SnackBar(
        content: Text('cannot reach backend — check Tailscale'),
      ),
    HttpStatusError(
      statusCode: final int statusCode,
      detail: final String? detail,
    ) =>
      SnackBar(
        content: Text('$statusCode: ${detail ?? 'request failed'}'),
      ),
  };
}

/// Show the appropriate snackbar for [error] and, for [UnauthorizedError],
/// redirect to `/settings` so the user can re-paste their token (PLAN §9).
///
/// The redirect is best-effort — it's a no-op in tests that mount a screen
/// without a `GoRouter` ancestor. Existing snackbars are dismissed so we
/// don't queue stale messages behind the new one.
void showApiError(
  BuildContext context,
  ApiError error, {
  String? action,
}) {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(buildApiErrorSnackBar(error, action: action));

  if (error is UnauthorizedError) {
    // Defer to the next microtask so the snackbar is mounted before the
    // route change. Skip the redirect when no router is available
    // (typical in widget-level tests of a single screen).
    Future<void>.microtask(() {
      if (!context.mounted) return;
      final GoRouter? router = GoRouter.maybeOf(context);
      if (router == null) return;
      router.go(Routes.settings);
    });
  }
}

/// Map an [AsyncValue] error to PLAN §9 UX **once per error-class
/// transition**. Wire from a screen's `build` via:
///
/// ```
/// ref.listen<AsyncValue<T>>(provider, (prev, next) =>
///     reactToApiError(context, prev, next));
/// ```
///
/// Subsequent ticks that produce the same error class don't re-snackbar,
/// so polling providers (queue, job status) don't spam the user.
void reactToApiError<T>(
  BuildContext context,
  AsyncValue<T>? prev,
  AsyncValue<T> next, {
  String? action,
}) {
  if (next is! AsyncError<T>) return;
  final Object err = next.error;
  if (err is! ApiError) return;
  final Object? prevErr = prev is AsyncError<T> ? prev.error : null;
  if (prevErr != null && prevErr.runtimeType == err.runtimeType) return;
  showApiError(context, err, action: action);
}
