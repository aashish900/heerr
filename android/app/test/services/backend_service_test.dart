import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/services/backend_service.dart';

// W1 (#41): container-free transport tests for the heerr-backend service,
// same pattern as subsonic_library_service_test.dart — a scripted adapter,
// no ProviderContainer.

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

(BackendService, _FakeAdapter) _service(
  FutureOr<ResponseBody> Function(RequestOptions) responder,
) {
  final _FakeAdapter adapter = _FakeAdapter(responder);
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'))
    ..httpClientAdapter = adapter;
  return (BackendService(dio), adapter);
}

ResponseBody _json(String body, int status) {
  return ResponseBody.fromString(
    body,
    status,
    headers: <String, List<String>>{
      'content-type': <String>['application/json'],
    },
  );
}

ResponseBody _noContent() => ResponseBody.fromString('', 204);

void main() {
  group('deleteLibrarySong', () {
    test('issues DELETE /library/song with the path in the body', () async {
      final (BackendService service, _FakeAdapter adapter) = _service(
        (_) => _json('{"deleted": true, "path": "A/B/01 - S.mp3"}', 200),
      );

      await service.deleteLibrarySong('A/B/01 - S.mp3');

      final RequestOptions req = adapter.lastRequest!;
      expect(req.method, 'DELETE');
      expect(req.path, '/library/song');
      expect(
        jsonEncode(req.data),
        jsonEncode(<String, String>{'path': 'A/B/01 - S.mp3'}),
      );
    });

    test('404 maps to NotFoundError', () async {
      final (BackendService service, _) = _service(
        (_) => _json('{"detail": "file not found in the music library"}', 404),
      );
      await expectLater(
        service.deleteLibrarySong('A/B/gone.mp3'),
        throwsA(isA<NotFoundError>()),
      );
    });

    test('403 maps to ForbiddenError', () async {
      final (BackendService service, _) = _service(
        (_) => _json('{"detail": "insufficient scope"}', 403),
      );
      await expectLater(
        service.deleteLibrarySong('A/B/01 - S.mp3'),
        throwsA(isA<ForbiddenError>()),
      );
    });

    test('connection failure maps to NetworkError', () async {
      final (BackendService service, _) = _service(
        (RequestOptions options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'refused',
        ),
      );
      await expectLater(
        service.deleteLibrarySong('A/B/01 - S.mp3'),
        throwsA(isA<NetworkError>()),
      );
    });
  });

  group('editLibrarySong', () {
    test('issues PATCH /library/song as multipart with only set fields',
        () async {
      final (BackendService service, _FakeAdapter adapter) = _service(
        (_) => _json('{"updated": true, "path": "A/B/01 - S.mp3", '
            '"fields": ["title", "artist"]}', 200),
      );

      await service.editLibrarySong(
        path: 'A/B/01 - S.mp3',
        title: 'New Title',
        artist: 'A, B',
      );

      final RequestOptions req = adapter.lastRequest!;
      expect(req.method, 'PATCH');
      expect(req.path, '/library/song');
      final FormData form = req.data as FormData;
      final Map<String, String> fields =
          <String, String>{for (final MapEntry<String, String> f in form.fields) f.key: f.value};
      expect(fields, <String, String>{
        'path': 'A/B/01 - S.mp3',
        'title': 'New Title',
        'artist': 'A, B',
      });
      expect(fields.containsKey('album'), isFalse);
      expect(form.files, isEmpty);
    });

    test('attaches the cover as a JPEG multipart file', () async {
      final (BackendService service, _FakeAdapter adapter) = _service(
        (_) => _json('{"updated": true, "path": "p.mp3", '
            '"fields": ["cover"]}', 200),
      );

      await service.editLibrarySong(
        path: 'p.mp3',
        coverBytes: Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0x00]),
      );

      final FormData form = (adapter.lastRequest!.data as FormData);
      expect(form.files, hasLength(1));
      final MapEntry<String, MultipartFile> cover = form.files.first;
      expect(cover.key, 'cover');
      expect(cover.value.filename, 'cover.jpg');
      expect(cover.value.contentType?.mimeType, 'image/jpeg');
    });

    test('404 maps to NotFoundError', () async {
      final (BackendService service, _) = _service(
        (_) => _json('{"detail": "file not found in the music library"}', 404),
      );
      await expectLater(
        service.editLibrarySong(path: 'gone.mp3', title: 'x'),
        throwsA(isA<NotFoundError>()),
      );
    });

    test('403 maps to ForbiddenError', () async {
      final (BackendService service, _) = _service(
        (_) => _json('{"detail": "insufficient scope"}', 403),
      );
      await expectLater(
        service.editLibrarySong(path: 'p.mp3', title: 'x'),
        throwsA(isA<ForbiddenError>()),
      );
    });

    test('connection failure maps to NetworkError', () async {
      final (BackendService service, _) = _service(
        (RequestOptions options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'refused',
        ),
      );
      await expectLater(
        service.editLibrarySong(path: 'p.mp3', title: 'x'),
        throwsA(isA<NetworkError>()),
      );
    });
  });

  group('logout', () {
    test('issues POST /auth/logout and completes on 204', () async {
      final (BackendService service, _FakeAdapter adapter) = _service(
        (_) => _noContent(),
      );

      await service.logout();

      expect(adapter.lastRequest!.method, 'POST');
      expect(adapter.lastRequest!.path, '/auth/logout');
    });

    test('401 maps to an ApiError (caller swallows it)', () async {
      final (BackendService service, _) = _service(
        (_) => _json('{"detail": "invalid or expired token"}', 401),
      );
      await expectLater(
        service.logout(),
        throwsA(isA<ApiError>()),
      );
    });

    test('connection failure maps to NetworkError', () async {
      final (BackendService service, _) = _service(
        (RequestOptions options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'refused',
        ),
      );
      await expectLater(
        service.logout(),
        throwsA(isA<NetworkError>()),
      );
    });
  });
}
