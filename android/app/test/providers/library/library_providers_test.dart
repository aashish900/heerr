import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/api/subsonic_client.dart';
import 'package:heerr/models/subsonic/album.dart';
import 'package:heerr/models/subsonic/artist.dart';
import 'package:heerr/models/subsonic/artist_index.dart';
import 'package:heerr/models/subsonic/playlist.dart';
import 'package:heerr/models/subsonic/search_result3.dart';
import 'package:heerr/providers/library/library_album.dart';
import 'package:heerr/providers/library/library_artist.dart';
import 'package:heerr/providers/library/library_artists.dart';
import 'package:heerr/providers/library/library_playlist.dart';
import 'package:heerr/providers/library/library_playlists.dart';
import 'package:heerr/providers/library/library_search.dart';
import 'package:heerr/providers/search.dart' show searchDebounceProvider;

// ---------------------------------------------------------------------------
// _FakeAdapter: same pattern as test/api/client_test.dart. Records the last
// request so tests can assert the request path and query params.
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

ResponseBody _jsonResponse(String body) {
  return ResponseBody.fromString(
    body,
    200,
    headers: <String, List<String>>{
      'content-type': <String>['application/json'],
    },
  );
}

ResponseBody _jsonFromFixture(String fixtureName) {
  return _jsonResponse(
    File('test/fixtures/subsonic/$fixtureName').readAsStringSync(),
  );
}

/// Build a `ProviderContainer` whose subsonicDioClient returns a stub dio
/// driven by [adapter]. Test overrides searchDebounce to zero so
/// librarySearch tests don't pay the 300ms tax.
ProviderContainer _containerWith(_FakeAdapter adapter) {
  return ProviderContainer(
    overrides: <Override>[
      subsonicDioClientProvider.overrideWith(
        (Ref<AsyncValue<Dio>> ref) async {
          final Dio dio = Dio(BaseOptions(baseUrl: 'http://navi.test'));
          dio.httpClientAdapter = adapter;
          return dio;
        },
      ),
      searchDebounceProvider.overrideWithValue(Duration.zero),
    ],
  );
}

void main() {
  group('libraryArtistsProvider', () {
    test('hits /rest/getArtists.view and returns the parsed index list',
        () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _jsonFromFixture('get_artists.json'),
      );
      final ProviderContainer c = _containerWith(adapter);
      addTearDown(c.dispose);

      final List<ArtistIndex> result =
          await c.read(libraryArtistsProvider.future);

      expect(adapter.lastRequest!.path, '/rest/getArtists.view');
      expect(result, hasLength(2));
      expect(result[0].name, 'A');
      expect(result[0].artist.first.name, 'Arctic Monkeys');
      expect(result[1].name, 'T');
      expect(result[1].artist, hasLength(2));
    });

    test('empty library (no "artists" key) → empty list', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _jsonResponse(
          jsonEncode(<String, dynamic>{
            'subsonic-response': <String, dynamic>{
              'status': 'ok',
              'version': '1.16.1',
            },
          }),
        ),
      );
      final ProviderContainer c = _containerWith(adapter);
      addTearDown(c.dispose);

      final List<ArtistIndex> result =
          await c.read(libraryArtistsProvider.future);
      expect(result, isEmpty);
    });
  });

  group('libraryArtistProvider(id)', () {
    test('hits /rest/getArtist.view?id=… and returns Artist with albums',
        () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _jsonFromFixture('get_artist.json'),
      );
      final ProviderContainer c = _containerWith(adapter);
      addTearDown(c.dispose);

      final Artist result =
          await c.read(libraryArtistProvider('ar-002').future);

      expect(adapter.lastRequest!.path, '/rest/getArtist.view');
      expect(adapter.lastRequest!.queryParameters['id'], 'ar-002');
      expect(result.name, 'Tame Impala');
      expect(result.album, hasLength(2));
      expect(result.album.first.name, 'Currents');
    });

    test('Subsonic code 70 → NotFoundError', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _jsonResponse(
          jsonEncode(<String, dynamic>{
            'subsonic-response': <String, dynamic>{
              'status': 'failed',
              'version': '1.16.1',
              'error': <String, dynamic>{
                'code': 70,
                'message': 'Artist not found.',
              },
            },
          }),
        ),
      );
      final ProviderContainer c = _containerWith(adapter);
      addTearDown(c.dispose);

      await expectLater(
        c.read(libraryArtistProvider('nope').future),
        throwsA(isA<NotFoundError>()),
      );
    });
  });

  group('libraryAlbumProvider(id)', () {
    test('hits /rest/getAlbum.view?id=… and returns Album with songs',
        () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _jsonFromFixture('get_album.json'),
      );
      final ProviderContainer c = _containerWith(adapter);
      addTearDown(c.dispose);

      final Album result =
          await c.read(libraryAlbumProvider('al-101').future);

      expect(adapter.lastRequest!.path, '/rest/getAlbum.view');
      expect(adapter.lastRequest!.queryParameters['id'], 'al-101');
      expect(result.name, 'Currents');
      expect(result.song, hasLength(3));
      expect(result.song.first.title, 'Let It Happen');
    });
  });

  group('libraryPlaylistsProvider', () {
    test('hits /rest/getPlaylists.view and returns the playlist list',
        () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _jsonFromFixture('get_playlists.json'),
      );
      final ProviderContainer c = _containerWith(adapter);
      addTearDown(c.dispose);

      final List<Playlist> result =
          await c.read(libraryPlaylistsProvider.future);

      expect(adapter.lastRequest!.path, '/rest/getPlaylists.view');
      expect(result, hasLength(2));
      expect(result.first.name, 'Morning Coffee');
      expect(result.first.entry, isEmpty);
    });

    test('user has no playlists (no "playlists" key) → empty list', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _jsonResponse(
          jsonEncode(<String, dynamic>{
            'subsonic-response': <String, dynamic>{
              'status': 'ok',
              'version': '1.16.1',
            },
          }),
        ),
      );
      final ProviderContainer c = _containerWith(adapter);
      addTearDown(c.dispose);

      final List<Playlist> result =
          await c.read(libraryPlaylistsProvider.future);
      expect(result, isEmpty);
    });
  });

  group('libraryPlaylistProvider(id)', () {
    test('hits /rest/getPlaylist.view?id=… and returns the playlist with entries',
        () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _jsonFromFixture('get_playlist.json'),
      );
      final ProviderContainer c = _containerWith(adapter);
      addTearDown(c.dispose);

      final Playlist result =
          await c.read(libraryPlaylistProvider('pl-01').future);

      expect(adapter.lastRequest!.path, '/rest/getPlaylist.view');
      expect(adapter.lastRequest!.queryParameters['id'], 'pl-01');
      expect(result.name, 'Morning Coffee');
      expect(result.entry, hasLength(2));
    });
  });

  group('librarySearchProvider(query)', () {
    test('empty query short-circuits to empty result, no request fired',
        () async {
      bool requested = false;
      final _FakeAdapter adapter = _FakeAdapter((_) {
        requested = true;
        return _jsonResponse('{}');
      });
      final ProviderContainer c = _containerWith(adapter);
      addTearDown(c.dispose);

      final SearchResult3 result =
          await c.read(librarySearchProvider('').future);

      expect(requested, isFalse);
      expect(result.artist, isEmpty);
      expect(result.album, isEmpty);
      expect(result.song, isEmpty);
    });

    test('whitespace-only query also short-circuits', () async {
      bool requested = false;
      final _FakeAdapter adapter = _FakeAdapter((_) {
        requested = true;
        return _jsonResponse('{}');
      });
      final ProviderContainer c = _containerWith(adapter);
      addTearDown(c.dispose);

      final SearchResult3 result =
          await c.read(librarySearchProvider('   ').future);

      expect(requested, isFalse);
      expect(result.song, isEmpty);
    });

    test(
        'non-empty query hits /rest/search3.view?query=… and returns parsed result',
        () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _jsonFromFixture('search3.json'),
      );
      final ProviderContainer c = _containerWith(adapter);
      addTearDown(c.dispose);

      // Hold the provider alive across the await; auto-dispose otherwise
      // disposes during the debounce delay and cancels the dio request via
      // the onDispose-bound CancelToken (same pattern as
      // test/providers/search_test.dart).
      c.listen<AsyncValue<SearchResult3>>(
        librarySearchProvider('Tame'),
        (_, _) {},
      );

      final SearchResult3 result =
          await c.read(librarySearchProvider('Tame').future);

      expect(adapter.lastRequest!.path, '/rest/search3.view');
      expect(adapter.lastRequest!.queryParameters['query'], 'Tame');
      expect(result.artist, hasLength(1));
      expect(result.album, hasLength(1));
      expect(result.song, hasLength(1));
    });

    test('missing searchResult3 key → empty result', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (_) => _jsonResponse(
          jsonEncode(<String, dynamic>{
            'subsonic-response': <String, dynamic>{
              'status': 'ok',
              'version': '1.16.1',
            },
          }),
        ),
      );
      final ProviderContainer c = _containerWith(adapter);
      addTearDown(c.dispose);

      c.listen<AsyncValue<SearchResult3>>(
        librarySearchProvider('xyz'),
        (_, _) {},
      );

      final SearchResult3 result =
          await c.read(librarySearchProvider('xyz').future);
      expect(result.artist, isEmpty);
    });
  });
}
