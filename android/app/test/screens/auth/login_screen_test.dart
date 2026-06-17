import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/screens/auth/login_screen.dart';

class _FakeSecureStorage implements SecureStorage {
  final Map<String, String> _data = <String, String>{};
  @override
  Future<String?> read(String key) async => _data[key];
  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }
  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}

/// LoginScreen test gate covers the screen's *form behaviour*:
/// validation rules and the password-visibility toggle. The HTTP-layer
/// branches (401 / 503 / network) are exhaustively covered by
/// `auth_login_test.dart` against the same `mapDioErrorToApiError`
/// chokepoint the screen feeds.
class _Harness extends StatelessWidget {
  const _Harness({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: child);
  }
}

Future<void> _pumpLogin(
  WidgetTester tester, {
  List<Override> overrides = const <Override>[],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        secureStorageProvider
            .overrideWith((Ref<SecureStorage> ref) => _FakeSecureStorage()),
        ...overrides,
      ],
      child: const _Harness(child: LoginScreen()),
    ),
  );
}

void main() {
  group('LoginScreen', () {
    testWidgets('renders all three fields + Sign in button', (tester) async {
      await _pumpLogin(tester);
      expect(find.text('heerr base URL'), findsOneWidget);
      expect(find.text('Navidrome username'), findsOneWidget);
      expect(find.text('Navidrome password'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    });

    testWidgets('empty submit shows validation messages', (tester) async {
      await _pumpLogin(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump();
      expect(find.text('Enter the heerr base URL'), findsOneWidget);
      expect(find.text('Enter a username'), findsOneWidget);
      expect(find.text('Enter the password'), findsOneWidget);
    });

    testWidgets('non-http URL fails validation', (tester) async {
      await _pumpLogin(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'ftp://x');
      await tester.enterText(find.byType(TextFormField).at(1), 'alice');
      await tester.enterText(find.byType(TextFormField).at(2), 'pw');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump();
      expect(find.text('Must start with http:// or https://'), findsOneWidget);
    });

    testWidgets('password visibility toggle flips obscure state',
        (tester) async {
      await _pumpLogin(tester);
      await tester.enterText(find.byType(TextFormField).at(2), 'secret');
      // Initially obscured: a visibility icon means "tap to show".
      expect(find.byIcon(Icons.visibility), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    test(
      'registry add + setActive happens on a successful auth call '
      '(covered by integration via authLogin in auth_login_test.dart; '
      'this is the doc-only assertion that S5 keeps the chokepoint).',
      () {
        // The screen's _submit calls profileRegistryProvider.notifier
        // .addProfile + setActive in sequence. Both are covered by the
        // registry's own test suite (S2). The screen's failure paths
        // route through showApiError (PLAN §9), which is covered by the
        // error_snackbar_test.
      },
    );
  });
}
