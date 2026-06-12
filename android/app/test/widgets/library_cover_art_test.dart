import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/offline/offline_downloader.dart';
import 'package:heerr/offline/offline_paths.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/widgets/library_cover_art.dart';

/// Widget tests for [LibraryCoverArt].
///
/// The richer assertions ("renders Image.file on cache hit", "renders
/// Image.network on cache miss") aren't here because `Image.file` under
/// `flutter_tester` triggers an image-decode pipeline that doesn't
/// terminate cleanly with our test runner — the test hangs in
/// `tester.pumpWidget`. The cache-write side effect (file lands on disk,
/// dio adapter is invoked exactly once) is the part the unit suite can
/// reliably observe; the visual rendering is left to the L6 device smoke.
class _FakeStorage implements SecureStorage {
  _FakeStorage(this._data);
  final Map<String, String> _data;
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

class _BytesAdapter implements HttpClientAdapter {
  _BytesAdapter(this.bytes);
  final List<int> bytes;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    calls += 1;
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: <String, List<String>>{
        'content-type': <String>['image/jpeg'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const Map<String, String> _kCreds = <String, String>{
  'navidrome_base_url': 'http://navi.test',
  'navidrome_username': 'u',
  'navidrome_password': 'p',
};

Widget _wrap({
  required Widget child,
  required Directory tmp,
  required _BytesAdapter adapter,
}) {
  return ProviderScope(
    overrides: <Override>[
      secureStorageProvider.overrideWith(
        (Ref<SecureStorage> ref) => _FakeStorage(_kCreds),
      ),
      applicationDocumentsDirectoryProvider
          .overrideWith((ApplicationDocumentsDirectoryRef ref) async => tmp),
      offlineDownloadDioProvider.overrideWith(
        (OfflineDownloadDioRef ref) {
          final Dio dio = Dio();
          dio.httpClientAdapter = adapter;
          return dio;
        },
      ),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

Future<void> _pump(WidgetTester tester) async {
  for (int i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('heerr-cover-');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  testWidgets('coverArtId null → renders placeholder, no download', (
    WidgetTester tester,
  ) async {
    final _BytesAdapter adapter = _BytesAdapter(<int>[1, 2, 3]);
    await tester.pumpWidget(_wrap(
      child: const LibraryCoverArt(coverArtId: null),
      tmp: tmp,
      adapter: adapter,
    ));
    await _pump(tester);
    expect(find.byIcon(Icons.music_note), findsOneWidget);
    expect(adapter.calls, 0);
  });
}
