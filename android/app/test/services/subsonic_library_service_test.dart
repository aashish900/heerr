import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/services/subsonic_library_service.dart';

// A10: the point of the service seam is that transport is testable WITHOUT a
// Riverpod container. These tests construct the service directly from a Dio
// wired to a scripted adapter — no ProviderContainer, no overrides.

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

ResponseBody _ok(String innerJson) {
  return ResponseBody.fromString(
    '{"subsonic-response":{"status":"ok","version":"1.16.1",$innerJson}}',
    200,
    headers: <String, List<String>>{
      'content-type': <String>['application/json'],
    },
  );
}

(SubsonicLibraryService, _FakeAdapter) _service(
  FutureOr<ResponseBody> Function(RequestOptions) responder,
) {
  final _FakeAdapter adapter = _FakeAdapter(responder);
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/rest'))
    ..httpClientAdapter = adapter;
  return (SubsonicLibraryService(dio), adapter);
}

void main() {
  test('getAlbums hits getAlbumList2 with the A-Z page size and parses', () async {
    final (SubsonicLibraryService service, _FakeAdapter adapter) = _service(
      (_) => _ok('"albumList2":{"album":[{"id":"al1","name":"A"},'
          '{"id":"al2","name":"B"}]}'),
    );

    final result = await service.getAlbums();

    expect(result.map((a) => a.id), <String>['al1', 'al2']);
    expect(adapter.lastRequest!.path, contains('getAlbumList2'));
    expect(adapter.lastRequest!.queryParameters['type'], 'alphabeticalByName');
    expect(
      adapter.lastRequest!.queryParameters['size'],
      SubsonicLibraryService.albumListPageSize,
    );
  });

  test('getArtists tolerates a library with no index', () async {
    final (SubsonicLibraryService service, _) = _service(
      (_) => _ok('"artists":{"ignoredArticles":""}'),
    );
    expect(await service.getArtists(), isEmpty);
  });

  test('findLibraryMatch returns the first song id + coverArt', () async {
    final (SubsonicLibraryService service, _FakeAdapter adapter) = _service(
      (_) => _ok('"searchResult3":{"song":[{"id":"s1","coverArt":"c1"}]}'),
    );

    final SubsonicSongMatch? match = await service.findLibraryMatch('foo bar');

    expect(match, isNotNull);
    expect(match!.id, 's1');
    expect(match.coverArt, 'c1');
    // Cross-ref probe forces a single-song search.
    expect(adapter.lastRequest!.queryParameters['songCount'], 1);
    expect(adapter.lastRequest!.queryParameters['artistCount'], 0);
  });

  test('findLibraryMatch short-circuits an empty query (no request)', () async {
    final (SubsonicLibraryService service, _FakeAdapter adapter) =
        _service((_) => _ok('"searchResult3":{}'));
    expect(await service.findLibraryMatch('   '), isNull);
    expect(adapter.lastRequest, isNull);
  });

  test('getStarredSongs parses the starred2 song block', () async {
    final (SubsonicLibraryService service, _) = _service(
      (_) => _ok('"starred2":{"song":[{"id":"s1","title":"T","artist":"A"}]}'),
    );
    final songs = await service.getStarredSongs();
    expect(songs.single.id, 's1');
  });
}
