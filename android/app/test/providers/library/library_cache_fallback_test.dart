import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/subsonic_client.dart';
import 'package:heerr/models/subsonic/album.dart';
import 'package:heerr/offline/offline_paths.dart';
import 'package:heerr/providers/library/library_album.dart';
import 'package:heerr/providers/library/library_albums.dart';
import 'package:heerr/providers/library/library_artist.dart';
import 'package:heerr/providers/library/library_artists.dart';
import 'package:heerr/providers/library/library_playlist.dart';
import 'package:heerr/providers/library/library_playlists.dart';
import 'package:heerr/providers/secure_storage.dart';

/// Live-network adapter for the first read, then errors-only for the
/// second. Provides a knob to flip "behave like offline backend" between
/// reads so a single test exercises both the cache-write and cache-read
/// paths.
class _ToggleAdapter implements HttpClientAdapter {
  _ToggleAdapter({required this.responder});

  FutureOr<ResponseBody> Function(RequestOptions options) responder;
  bool failNext = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    if (failNext) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'simulated offline',
      );
    }
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

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

ResponseBody _json(String body) => ResponseBody.fromString(
      body,
      200,
      headers: <String, List<String>>{
        'content-type': <String>['application/json'],
      },
    );

ProviderContainer _container({
  required _ToggleAdapter adapter,
  required Directory tmp,
}) {
  return ProviderContainer(
    overrides: <Override>[
      secureStorageProvider.overrideWith(
        (Ref<SecureStorage> ref) => _FakeStorage(<String, String>{
          'navidrome_base_url': 'http://navi.test',
          'navidrome_username': 'u',
          'navidrome_password': 'p',
        }),
      ),
      applicationDocumentsDirectoryProvider
          .overrideWith((ApplicationDocumentsDirectoryRef ref) async => tmp),
      subsonicDioClientProvider.overrideWith(
        (Ref<AsyncValue<Dio>> ref) async {
          final Dio dio = Dio(BaseOptions(baseUrl: 'http://navi.test'));
          dio.httpClientAdapter = adapter;
          return dio;
        },
      ),
    ],
  );
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('heerr-cache-fb-');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('Library providers — cache fallback', () {
    test('libraryAlbumsProvider serves cached value on network failure',
        () async {
      final _ToggleAdapter adapter = _ToggleAdapter(
        responder: (_) => _json(
          '{"subsonic-response":{"status":"ok","version":"1.16.1",'
          '"albumList2":{"album":[{"id":"al-1","name":"Currents"}]}}}',
        ),
      );
      final ProviderContainer c = _container(adapter: adapter, tmp: tmp);
      addTearDown(c.dispose);

      // First read — online. Cache is populated.
      final List<Album> live =
          await c.read(libraryAlbumsProvider.future);
      expect(live, hasLength(1));
      expect(live.first.id, 'al-1');

      // Flip the adapter to "offline" + invalidate the provider so the
      // next read reruns build().
      adapter.failNext = true;
      c.invalidate(libraryAlbumsProvider);

      final List<Album> cached =
          await c.read(libraryAlbumsProvider.future);
      expect(cached, hasLength(1));
      expect(cached.first.id, 'al-1');
    });

    test('libraryAlbumProvider(id) serves cached value on network failure',
        () async {
      final _ToggleAdapter adapter = _ToggleAdapter(
        responder: (_) => _json(
          '{"subsonic-response":{"status":"ok","version":"1.16.1",'
          '"album":{"id":"al-1","name":"X","song":'
          '[{"id":"so-1","title":"t1"}]}}}',
        ),
      );
      final ProviderContainer c = _container(adapter: adapter, tmp: tmp);
      addTearDown(c.dispose);

      final Album live =
          await c.read(libraryAlbumProvider('al-1').future);
      expect(live.song, hasLength(1));

      adapter.failNext = true;
      c.invalidate(libraryAlbumProvider('al-1'));

      final Album cached =
          await c.read(libraryAlbumProvider('al-1').future);
      expect(cached.song, hasLength(1));
      expect(cached.song.first.id, 'so-1');
    });

    test('libraryArtistsProvider serves cached value on network failure',
        () async {
      final _ToggleAdapter adapter = _ToggleAdapter(
        responder: (_) => _json(
          '{"subsonic-response":{"status":"ok","version":"1.16.1",'
          '"artists":{"ignoredArticles":"","index":'
          '[{"name":"A","artist":[{"id":"ar-1","name":"Arctic Monkeys"}]}]}}}',
        ),
      );
      final ProviderContainer c = _container(adapter: adapter, tmp: tmp);
      addTearDown(c.dispose);

      await c.read(libraryArtistsProvider.future);
      adapter.failNext = true;
      c.invalidate(libraryArtistsProvider);

      final result = await c.read(libraryArtistsProvider.future);
      expect(result, hasLength(1));
      expect(result.first.name, 'A');
    });

    test('libraryArtistProvider(id) serves cached value on network failure',
        () async {
      final _ToggleAdapter adapter = _ToggleAdapter(
        responder: (_) => _json(
          '{"subsonic-response":{"status":"ok","version":"1.16.1",'
          '"artist":{"id":"ar-1","name":"Arctic Monkeys","album":'
          '[{"id":"al-1","name":"AM"}]}}}',
        ),
      );
      final ProviderContainer c = _container(adapter: adapter, tmp: tmp);
      addTearDown(c.dispose);

      await c.read(libraryArtistProvider('ar-1').future);
      adapter.failNext = true;
      c.invalidate(libraryArtistProvider('ar-1'));

      final result = await c.read(libraryArtistProvider('ar-1').future);
      expect(result.name, 'Arctic Monkeys');
      expect(result.album, hasLength(1));
    });

    test('libraryPlaylistsProvider serves cached value on network failure',
        () async {
      final _ToggleAdapter adapter = _ToggleAdapter(
        responder: (_) => _json(
          '{"subsonic-response":{"status":"ok","version":"1.16.1",'
          '"playlists":{"playlist":[{"id":"pl-1","name":"Faves"}]}}}',
        ),
      );
      final ProviderContainer c = _container(adapter: adapter, tmp: tmp);
      addTearDown(c.dispose);

      await c.read(libraryPlaylistsProvider.future);
      adapter.failNext = true;
      c.invalidate(libraryPlaylistsProvider);

      final result = await c.read(libraryPlaylistsProvider.future);
      expect(result, hasLength(1));
      expect(result.first.id, 'pl-1');
    });

    test('libraryPlaylistProvider(id) serves cached value on network failure',
        () async {
      final _ToggleAdapter adapter = _ToggleAdapter(
        responder: (_) => _json(
          '{"subsonic-response":{"status":"ok","version":"1.16.1",'
          '"playlist":{"id":"pl-1","name":"Faves","entry":'
          '[{"id":"so-1","title":"t1"}]}}}',
        ),
      );
      final ProviderContainer c = _container(adapter: adapter, tmp: tmp);
      addTearDown(c.dispose);

      await c.read(libraryPlaylistProvider('pl-1').future);
      adapter.failNext = true;
      c.invalidate(libraryPlaylistProvider('pl-1'));

      final result = await c.read(libraryPlaylistProvider('pl-1').future);
      expect(result.entry, hasLength(1));
    });

    test('no prior cache + network failure → propagates the error', () async {
      final _ToggleAdapter adapter = _ToggleAdapter(
        responder: (_) => _json('{"subsonic-response":{"status":"ok"}}'),
      );
      adapter.failNext = true;
      final ProviderContainer c = _container(adapter: adapter, tmp: tmp);
      addTearDown(c.dispose);

      // subsonicCall maps DioException → an ApiError; whatever shape it
      // takes, the point is the error propagates (no cache to fall back to).
      await expectLater(
        c.read(libraryAlbumsProvider.future),
        throwsA(anything),
      );
    });
  });
}
