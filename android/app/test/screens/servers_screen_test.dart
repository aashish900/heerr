import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/subsonic_client.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/screens/servers_screen.dart';

// ---------------------------------------------------------------------------
// Plumbing: in-memory secure-storage fake (so ServerProfiles read/write
// without the platform channel) + a fake dio adapter that returns whatever
// envelope the test sets.
// ---------------------------------------------------------------------------
class _InMemoryStorage implements SecureStorage {
  _InMemoryStorage();
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

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responder);
  final FutureOr<ResponseBody> Function(RequestOptions options) responder;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
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

Map<String, dynamic> _okPing() => <String, dynamic>{
      'subsonic-response': <String, dynamic>{
        'status': 'ok',
        'version': '1.16.1',
      },
    };

Map<String, dynamic> _failedPing() => <String, dynamic>{
      'subsonic-response': <String, dynamic>{
        'status': 'failed',
        'version': '1.16.1',
        'error': <String, dynamic>{
          'code': 40,
          'message': 'Wrong username or password.',
        },
      },
    };

Future<Dio> _stubDio(Map<String, dynamic> envelope) async {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://navi.test'));
  dio.httpClientAdapter = _FakeAdapter((_) => _json(200, envelope));
  return dio;
}

Widget _wrap(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(home: ServersScreen()),
  );
}

Future<void> _fillForm(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Server name'),
    'Home',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Backend URL'),
    'http://heerr.test:8000/api/v1',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Bearer token'),
    'tok-1',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Navidrome URL'),
    'http://navi.test:4533',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Navidrome username'),
    'me',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Navidrome password'),
    'pw',
  );
}

Future<void> _openForm(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Test Navidrome against ok envelope → "Connection OK" snackbar',
    (WidgetTester tester) async {
      final _InMemoryStorage store = _InMemoryStorage();
      await tester.pumpWidget(_wrap(<Override>[
        secureStorageProvider.overrideWithValue(store),
        subsonicDioClientProvider.overrideWith(
          (Ref<AsyncValue<Dio>> ref) async => _stubDio(_okPing()),
        ),
      ]));
      await tester.pumpAndSettle();

      await _openForm(tester);
      await _fillForm(tester);

      // Scroll buttons into view (form is longer than the default 600px test
      // screen after the navidrome section was added).
      await tester.ensureVisible(find.text('Test Navidrome'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test Navidrome'));
      await tester.pump(); // start the request
      await tester.pump(const Duration(milliseconds: 50)); // resolve the future

      expect(find.text('Connection OK'), findsOneWidget);
    },
  );

  testWidgets(
    'Test Navidrome against code 40 envelope → snackbar carries Subsonic detail',
    (WidgetTester tester) async {
      final _InMemoryStorage store = _InMemoryStorage();
      await tester.pumpWidget(_wrap(<Override>[
        secureStorageProvider.overrideWithValue(store),
        subsonicDioClientProvider.overrideWith(
          (Ref<AsyncValue<Dio>> ref) async => _stubDio(_failedPing()),
        ),
      ]));
      await tester.pumpAndSettle();

      await _openForm(tester);
      await _fillForm(tester);

      await tester.ensureVisible(find.text('Test Navidrome'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test Navidrome'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // K1 maps Subsonic code 40 to NavidromeAuthError with dedicated copy.
      expect(find.text('Connection OK'), findsNothing);
      expect(
        find.text('wrong Navidrome username or password — check Settings'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Test Navidrome with missing navidrome fields → guard snackbar, no request',
    (WidgetTester tester) async {
      final _InMemoryStorage store = _InMemoryStorage();
      bool requested = false;
      await tester.pumpWidget(_wrap(<Override>[
        secureStorageProvider.overrideWithValue(store),
        subsonicDioClientProvider.overrideWith(
          (Ref<AsyncValue<Dio>> ref) async {
            final Dio dio = Dio(BaseOptions(baseUrl: 'http://navi.test'));
            dio.httpClientAdapter = _FakeAdapter((_) {
              requested = true;
              return _json(200, _okPing());
            });
            return dio;
          },
        ),
      ]));
      await tester.pumpAndSettle();

      await _openForm(tester);
      // Fill heerr fields only.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Server name'),
        'Home',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Backend URL'),
        'http://heerr.test:8000/api/v1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Bearer token'),
        'tok-1',
      );

      await tester.ensureVisible(find.text('Test Navidrome'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test Navidrome'));
      await tester.pump();

      expect(find.text('Fill in all 3 Navidrome fields first'), findsOneWidget);
      expect(requested, isFalse);
    },
  );
}
