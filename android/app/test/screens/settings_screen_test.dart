import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/client.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/screens/settings_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responder);
  final FutureOr<ResponseBody> Function(RequestOptions options) responder;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    lastRequest = options;
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

class _InMemoryStorage implements SecureStorage {
  _InMemoryStorage([Map<String, String>? seed])
    : _data = <String, String>{...?seed};
  final Map<String, String> _data;
  Map<String, String> get snapshot => Map<String, String>.unmodifiable(_data);

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

ResponseBody _json(int statusCode, Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      'content-type': <String>['application/json'],
    },
  );
}

Widget _wrap({required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(home: SettingsScreen()),
  );
}

// Build a Dio whose adapter is the given _FakeAdapter. The dio bypasses
// `dioClientProvider`'s normal `settings → dio` wiring; we hand it directly
// to consumers via override. baseUrl is set so request paths line up with
// production code.
Dio _dioWithFake(_FakeAdapter adapter) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
  dio.httpClientAdapter = adapter;
  return dio;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  testWidgets('renders the form with empty fields on fresh storage', (
    WidgetTester tester,
  ) async {
    final _InMemoryStorage store = _InMemoryStorage();
    await tester.pumpWidget(
      _wrap(
        overrides: <Override>[
          secureStorageProvider.overrideWith((Ref<SecureStorage> _) => store),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Backend URL'), findsOneWidget);
    expect(find.text('Bearer token'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Test connection'),
      findsOneWidget,
    );
  });

  testWidgets('pre-populates fields from existing storage', (
    WidgetTester tester,
  ) async {
    final _InMemoryStorage store = _InMemoryStorage(<String, String>{
      'backend_base_url': 'http://x:8000/api/v1',
      'bearer_token': 'tok-pre',
    });
    await tester.pumpWidget(
      _wrap(
        overrides: <Override>[
          secureStorageProvider.overrideWith((Ref<SecureStorage> _) => store),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final TextField urlField =
        tester.widget<TextField>(find.byType(TextField).at(0));
    final TextField tokenField =
        tester.widget<TextField>(find.byType(TextField).at(1));
    expect(urlField.controller!.text, 'http://x:8000/api/v1');
    expect(tokenField.controller!.text, 'tok-pre');
  });

  testWidgets('Save validates + persists + shows snackbar', (
    WidgetTester tester,
  ) async {
    final _InMemoryStorage store = _InMemoryStorage();
    await tester.pumpWidget(
      _wrap(
        overrides: <Override>[
          secureStorageProvider.overrideWith((Ref<SecureStorage> _) => store),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).at(0),
      'http://my-host:8000/api/v1',
    );
    await tester.enterText(find.byType(TextField).at(1), 'tok-1');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Saved'), findsOneWidget);
    expect(store.snapshot, <String, String>{
      'backend_base_url': 'http://my-host:8000/api/v1',
      'bearer_token': 'tok-1',
    });
  });

  testWidgets('Save normalizes trailing slashes in URL', (
    WidgetTester tester,
  ) async {
    final _InMemoryStorage store = _InMemoryStorage();
    await tester.pumpWidget(
      _wrap(
        overrides: <Override>[
          secureStorageProvider.overrideWith((Ref<SecureStorage> _) => store),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).at(0),
      'http://x:8000/api/v1///',
    );
    await tester.enterText(find.byType(TextField).at(1), 'tok');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(store.snapshot['backend_base_url'], 'http://x:8000/api/v1');
  });

  testWidgets('Save shows validation error when URL is blank', (
    WidgetTester tester,
  ) async {
    final _InMemoryStorage store = _InMemoryStorage();
    await tester.pumpWidget(
      _wrap(
        overrides: <Override>[
          secureStorageProvider.overrideWith((Ref<SecureStorage> _) => store),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('required'), findsNWidgets(2));
    expect(store.snapshot, isEmpty);
  });

  testWidgets('Save rejects URL without http(s) scheme', (
    WidgetTester tester,
  ) async {
    final _InMemoryStorage store = _InMemoryStorage();
    await tester.pumpWidget(
      _wrap(
        overrides: <Override>[
          secureStorageProvider.overrideWith((Ref<SecureStorage> _) => store),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'my-host:8000/api/v1');
    await tester.enterText(find.byType(TextField).at(1), 'tok');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('must start with http:// or https://'), findsOneWidget);
  });

  testWidgets('Test connection on 200 shows "Connection OK"', (
    WidgetTester tester,
  ) async {
    final _InMemoryStorage store = _InMemoryStorage();
    final _FakeAdapter adapter = _FakeAdapter(
      (_) => _json(200, <String, dynamic>{'status': 'ok'}),
    );
    final Dio fakeDio = _dioWithFake(adapter);

    await tester.pumpWidget(
      _wrap(
        overrides: <Override>[
          secureStorageProvider.overrideWith((Ref<SecureStorage> _) => store),
          dioClientProvider.overrideWith((_) => fakeDio),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).at(0),
      'http://x:8000/api/v1',
    );
    await tester.enterText(find.byType(TextField).at(1), 'tok');
    await tester.tap(find.widgetWithText(FilledButton, 'Test connection'));
    await tester.pumpAndSettle();

    expect(find.text('Connection OK'), findsOneWidget);
    expect(adapter.lastRequest!.path, '/health');
  });

  testWidgets('Test connection on 401 shows the mapped error', (
    WidgetTester tester,
  ) async {
    final _InMemoryStorage store = _InMemoryStorage();
    final _FakeAdapter adapter = _FakeAdapter(
      (_) => _json(401, <String, dynamic>{'detail': 'bad token'}),
    );
    final Dio fakeDio = _dioWithFake(adapter);

    await tester.pumpWidget(
      _wrap(
        overrides: <Override>[
          secureStorageProvider.overrideWith((Ref<SecureStorage> _) => store),
          dioClientProvider.overrideWith((_) => fakeDio),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).at(0),
      'http://x:8000/api/v1',
    );
    await tester.enterText(find.byType(TextField).at(1), 'tok');
    await tester.tap(find.widgetWithText(FilledButton, 'Test connection'));
    await tester.pumpAndSettle();

    // The snackbar text is "Connection failed: <ApiError.message>" — for
    // UnauthorizedError that's the backend's detail string.
    expect(find.textContaining('Connection failed'), findsOneWidget);
    expect(find.textContaining('bad token'), findsOneWidget);
  });
}
