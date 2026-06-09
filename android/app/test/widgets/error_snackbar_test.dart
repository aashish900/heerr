import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/router.dart';
import 'package:heerr/widgets/error_snackbar.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _harness({required void Function(BuildContext) onPressed}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (BuildContext context) {
          return Center(
            child: ElevatedButton(
              onPressed: () => onPressed(context),
              child: const Text('go'),
            ),
          );
        },
      ),
    ),
  );
}

Future<void> _tapTrigger(WidgetTester tester) async {
  await tester.tap(find.text('go'));
  await tester.pump(); // snackbar enters
  await tester.pump(const Duration(milliseconds: 100));
}

// ---------------------------------------------------------------------------
// Tests — one per PLAN.md §9 row.
// ---------------------------------------------------------------------------

void main() {
  group('buildApiErrorSnackBar — PLAN §9 copy', () {
    testWidgets('401 UnauthorizedError → "auth failed — re-paste your token"', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(
        onPressed: (BuildContext c) => showApiError(
          c,
          const UnauthorizedError(detail: 'bad token'),
        ),
      ));
      await _tapTrigger(tester);
      expect(find.text('auth failed — re-paste your token'), findsOneWidget);
    });

    testWidgets('403 ForbiddenError with action → "this token cannot <action>"', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(
        onPressed: (BuildContext c) => showApiError(
          c,
          const ForbiddenError(),
          action: 'download',
        ),
      ));
      await _tapTrigger(tester);
      expect(find.text('this token cannot download'), findsOneWidget);
    });

    testWidgets('403 ForbiddenError without action → backend detail or fallback', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(
        onPressed: (BuildContext c) => showApiError(
          c,
          const ForbiddenError(detail: 'admin required'),
        ),
      ));
      await _tapTrigger(tester);
      expect(find.text('admin required'), findsOneWidget);
    });

    testWidgets('422 UnprocessableError → backend detail', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(
        onPressed: (BuildContext c) => showApiError(
          c,
          const UnprocessableError(detail: 'invalid spotify URI'),
        ),
      ));
      await _tapTrigger(tester);
      expect(find.text('invalid spotify URI'), findsOneWidget);
    });

    testWidgets('503 RateLimitedError → "Spotify rate-limited — retry in Ns"', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(
        onPressed: (BuildContext c) => showApiError(
          c,
          const RateLimitedError(retryAfter: Duration(seconds: 7)),
        ),
      ));
      await _tapTrigger(tester);
      expect(
        find.text('Spotify rate-limited — retry in 7s'),
        findsOneWidget,
      );
    });

    testWidgets('NetworkError → "cannot reach backend — check Tailscale"', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(
        onPressed: (BuildContext c) => showApiError(c, const NetworkError()),
      ));
      await _tapTrigger(tester);
      expect(
        find.text('cannot reach backend — check Tailscale'),
        findsOneWidget,
      );
    });

    testWidgets('HttpStatusError → "<code>: <detail>"', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(
        onPressed: (BuildContext c) => showApiError(
          c,
          const HttpStatusError(statusCode: 500, detail: 'internal'),
        ),
      ));
      await _tapTrigger(tester);
      expect(find.text('500: internal'), findsOneWidget);
    });

    testWidgets('HttpStatusError without detail → fallback "request failed"', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(
        onPressed: (BuildContext c) => showApiError(
          c,
          const HttpStatusError(statusCode: 500),
        ),
      ));
      await _tapTrigger(tester);
      expect(find.text('500: request failed'), findsOneWidget);
    });
  });

  group('showApiError — 401 side-effect', () {
    testWidgets('UnauthorizedError redirects to /settings when a router exists',
        (WidgetTester tester) async {
      // Minimal two-route GoRouter so we can observe the navigation.
      final GoRouter router = GoRouter(
        initialLocation: '/',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: Builder(
                builder: (BuildContext c) => Center(
                  child: ElevatedButton(
                    onPressed: () =>
                        showApiError(c, const UnauthorizedError()),
                    child: const Text('go'),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: Routes.settings,
            builder: (_, _) => const Scaffold(body: Text('SETTINGS')),
          ),
        ],
      );

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('go'));
      await tester.pump(); // snackbar
      await tester.pump(); // microtask → go
      await tester.pumpAndSettle();

      expect(find.text('SETTINGS'), findsOneWidget);
    });

    testWidgets('UnauthorizedError does NOT crash without a GoRouter ancestor',
        (WidgetTester tester) async {
      // The harness has MaterialApp but no GoRouter — showApiError should be
      // a no-op for the redirect leg and just show the snackbar.
      await tester.pumpWidget(_harness(
        onPressed: (BuildContext c) =>
            showApiError(c, const UnauthorizedError()),
      ));
      await _tapTrigger(tester);
      expect(find.text('auth failed — re-paste your token'), findsOneWidget);
      // No exception thrown — test passes if we get here.
    });
  });
}
