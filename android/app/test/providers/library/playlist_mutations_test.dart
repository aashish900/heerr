import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/api/subsonic_client.dart';
import 'package:heerr/models/subsonic/playlist.dart';
import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/providers/library/favourites.dart';
import 'package:heerr/providers/library/library_playlist.dart';
import 'package:heerr/providers/library/library_playlists.dart';
import 'package:heerr/providers/library/playlist_mutations.dart';

// ---------------------------------------------------------------------------
// Routing adapter: dispatches by request path. Records every RequestOptions
// so tests can count hits per endpoint and inspect query params. Same
// pattern as test/providers/library/library_providers_test.dart but
// keyed by path so a single test can prime a read-provider AND issue a
// mutation through the same dio.
// ---------------------------------------------------------------------------
class _RouterAdapter implements HttpClientAdapter {
  _RouterAdapter(this._routes);

  final Map<String, FutureOr<ResponseBody> Function(RequestOptions options)>
      _routes;

  final List<RequestOptions> requests = <RequestOptions>[];

  int countFor(String path) =>
      requests.where((RequestOptions r) => r.path == path).length;

  RequestOptions? lastFor(String path) {
    for (int i = requests.length - 1; i >= 0; i--) {
      if (requests[i].path == path) return requests[i];
    }
    return null;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    requests.add(options);
    final FutureOr<ResponseBody> Function(RequestOptions)? fn =
        _routes[options.path];
    if (fn == null) {
      return ResponseBody.fromString(
        jsonEncode(<String, dynamic>{
          'subsonic-response': <String, dynamic>{
            'status': 'failed',
            'version': '1.16.1',
            'error': <String, dynamic>{
              'code': 0,
              'message': 'unrouted path: ${options.path}',
            },
          },
        }),
        200,
        headers: <String, List<String>>{
          'content-type': <String>['application/json'],
        },
      );
    }
    return fn(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _ok(Map<String, dynamic> envelopePayload) {
  return ResponseBody.fromString(
    jsonEncode(<String, dynamic>{
      'subsonic-response': <String, dynamic>{
        'status': 'ok',
        'version': '1.16.1',
        ...envelopePayload,
      },
    }),
    200,
    headers: <String, List<String>>{
      'content-type': <String>['application/json'],
    },
  );
}

ResponseBody _emptyOk() => _ok(<String, dynamic>{});

ResponseBody _failed({required int code, required String message}) {
  return ResponseBody.fromString(
    jsonEncode(<String, dynamic>{
      'subsonic-response': <String, dynamic>{
        'status': 'failed',
        'version': '1.16.1',
        'error': <String, dynamic>{'code': code, 'message': message},
      },
    }),
    200,
    headers: <String, List<String>>{
      'content-type': <String>['application/json'],
    },
  );
}

ResponseBody _playlistsList() {
  return _ok(<String, dynamic>{
    'playlists': <String, dynamic>{
      'playlist': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'pl-01',
          'name': 'Morning Coffee',
          'songCount': 2,
          'duration': 575,
          'owner': 'phone',
          'public': false,
        },
      ],
    },
  });
}

ResponseBody _playlistDetail(String id) {
  return _ok(<String, dynamic>{
    'playlist': <String, dynamic>{
      'id': id,
      'name': 'Morning Coffee',
      'songCount': 0,
      'duration': 0,
      'owner': 'phone',
      'public': false,
      'entry': <Map<String, dynamic>>[],
    },
  });
}

Map<String, dynamic> _newPlaylistEnvelope({required String id, required String name}) {
  return <String, dynamic>{
    'playlist': <String, dynamic>{
      'id': id,
      'name': name,
      'songCount': 0,
      'duration': 0,
      'owner': 'phone',
      'public': false,
      'entry': <Map<String, dynamic>>[],
    },
  };
}

ProviderContainer _containerWith(_RouterAdapter adapter) {
  return ProviderContainer(
    overrides: <Override>[
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

/// Read multi-param values for [key] off the captured request, in the
/// order dio sent them. dio collapses `List<String>` query values into
/// repeated `key=v1&key=v2` pairs; on the receiving side
/// `RequestOptions.queryParameters` exposes them either as `List` (the
/// dio default for repeated keys) or as the raw value if there's only
/// one. This helper normalises both.
List<String> _multi(RequestOptions req, String key) {
  final dynamic v = req.queryParameters[key];
  if (v == null) return const <String>[];
  if (v is List) return v.map((dynamic e) => e.toString()).toList();
  return <String>[v.toString()];
}

void main() {
  group('PlaylistMutations.createPlaylist', () {
    test(
      'hits /rest/createPlaylist.view with name= and returns the new Playlist',
      () async {
        final _RouterAdapter adapter = _RouterAdapter(
          <String, FutureOr<ResponseBody> Function(RequestOptions)>{
            '/rest/createPlaylist.view': (_) =>
                _ok(_newPlaylistEnvelope(id: 'pl-99', name: 'Test')),
          },
        );
        final ProviderContainer c = _containerWith(adapter);
        addTearDown(c.dispose);

        final Playlist created = await c
            .read(playlistMutationsProvider.notifier)
            .createPlaylist(name: 'Test');

        final RequestOptions req = adapter.lastFor(
          '/rest/createPlaylist.view',
        )!;
        expect(req.queryParameters['name'], 'Test');
        expect(req.queryParameters.containsKey('songId'), isFalse);
        expect(created.id, 'pl-99');
        expect(created.name, 'Test');
      },
    );

    test('with songIds populated → songId multi-param in order', () async {
      final _RouterAdapter adapter = _RouterAdapter(
        <String, FutureOr<ResponseBody> Function(RequestOptions)>{
          '/rest/createPlaylist.view': (_) =>
              _ok(_newPlaylistEnvelope(id: 'pl-99', name: 'Test')),
        },
      );
      final ProviderContainer c = _containerWith(adapter);
      addTearDown(c.dispose);

      await c.read(playlistMutationsProvider.notifier).createPlaylist(
        name: 'Test',
        songIds: <String>['a', 'b', 'c'],
      );

      final RequestOptions req = adapter.lastFor(
        '/rest/createPlaylist.view',
      )!;
      expect(_multi(req, 'songId'), <String>['a', 'b', 'c']);
    });

    test('invalidates libraryPlaylistsProvider on success', () async {
      final _RouterAdapter adapter = _RouterAdapter(
        <String, FutureOr<ResponseBody> Function(RequestOptions)>{
          '/rest/getPlaylists.view': (_) => _playlistsList(),
          '/rest/createPlaylist.view': (_) =>
              _ok(_newPlaylistEnvelope(id: 'pl-99', name: 'Test')),
        },
      );
      final ProviderContainer c = _containerWith(adapter);
      addTearDown(c.dispose);

      // Keep the read provider active across the mutation so invalidation
      // forces a refetch instead of a silent cache-drop.
      c.listen<AsyncValue<List<Playlist>>>(
        libraryPlaylistsProvider,
        (_, _) {},
      );
      await c.read(libraryPlaylistsProvider.future);
      expect(adapter.countFor('/rest/getPlaylists.view'), 1);

      await c
          .read(playlistMutationsProvider.notifier)
          .createPlaylist(name: 'Test');
      await c.read(libraryPlaylistsProvider.future);

      expect(adapter.countFor('/rest/getPlaylists.view'), 2);
    });

    test('Subsonic failed envelope → ApiError, no invalidation', () async {
      final _RouterAdapter adapter = _RouterAdapter(
        <String, FutureOr<ResponseBody> Function(RequestOptions)>{
          '/rest/getPlaylists.view': (_) => _playlistsList(),
          '/rest/createPlaylist.view': (_) =>
              _failed(code: 50, message: 'not authorized'),
        },
      );
      final ProviderContainer c = _containerWith(adapter);
      addTearDown(c.dispose);

      c.listen<AsyncValue<List<Playlist>>>(
        libraryPlaylistsProvider,
        (_, _) {},
      );
      await c.read(libraryPlaylistsProvider.future);
      expect(adapter.countFor('/rest/getPlaylists.view'), 1);

      await expectLater(
        c
            .read(playlistMutationsProvider.notifier)
            .createPlaylist(name: 'Test'),
        throwsA(isA<ForbiddenError>()),
      );
      await c.read(libraryPlaylistsProvider.future);
      // No invalidation on failure.
      expect(adapter.countFor('/rest/getPlaylists.view'), 1);
    });
  });

  group('PlaylistMutations.renamePlaylist', () {
    test(
      'hits /rest/updatePlaylist.view with playlistId + name; '
      'invalidates list + detail',
      () async {
        final _RouterAdapter adapter = _RouterAdapter(
          <String, FutureOr<ResponseBody> Function(RequestOptions)>{
            '/rest/getPlaylists.view': (_) => _playlistsList(),
            '/rest/getPlaylist.view': (_) => _playlistDetail('pl-01'),
            '/rest/updatePlaylist.view': (_) => _emptyOk(),
          },
        );
        final ProviderContainer c = _containerWith(adapter);
        addTearDown(c.dispose);

        c.listen<AsyncValue<List<Playlist>>>(
          libraryPlaylistsProvider,
          (_, _) {},
        );
        c.listen<AsyncValue<Playlist>>(
          libraryPlaylistProvider('pl-01'),
          (_, _) {},
        );
        await c.read(libraryPlaylistsProvider.future);
        await c.read(libraryPlaylistProvider('pl-01').future);

        await c.read(playlistMutationsProvider.notifier).renamePlaylist(
          playlistId: 'pl-01',
          name: 'Renamed',
        );

        final RequestOptions req = adapter.lastFor(
          '/rest/updatePlaylist.view',
        )!;
        expect(req.queryParameters['playlistId'], 'pl-01');
        expect(req.queryParameters['name'], 'Renamed');
        expect(req.queryParameters.containsKey('public'), isFalse);

        await c.read(libraryPlaylistsProvider.future);
        await c.read(libraryPlaylistProvider('pl-01').future);
        expect(adapter.countFor('/rest/getPlaylists.view'), 2);
        expect(adapter.countFor('/rest/getPlaylist.view'), 2);
      },
    );

    test('makePublic: true → public=true query param', () async {
      final _RouterAdapter adapter = _RouterAdapter(
        <String, FutureOr<ResponseBody> Function(RequestOptions)>{
          '/rest/updatePlaylist.view': (_) => _emptyOk(),
        },
      );
      final ProviderContainer c = _containerWith(adapter);
      addTearDown(c.dispose);

      await c.read(playlistMutationsProvider.notifier).renamePlaylist(
        playlistId: 'pl-01',
        name: 'X',
        makePublic: true,
      );

      final RequestOptions req = adapter.lastFor(
        '/rest/updatePlaylist.view',
      )!;
      expect(req.queryParameters['public'], 'true');
    });

    test('Subsonic code 70 → NotFoundError', () async {
      final _RouterAdapter adapter = _RouterAdapter(
        <String, FutureOr<ResponseBody> Function(RequestOptions)>{
          '/rest/updatePlaylist.view': (_) =>
              _failed(code: 70, message: 'not found'),
        },
      );
      final ProviderContainer c = _containerWith(adapter);
      addTearDown(c.dispose);

      await expectLater(
        c.read(playlistMutationsProvider.notifier).renamePlaylist(
          playlistId: 'pl-00',
          name: 'X',
        ),
        throwsA(isA<NotFoundError>()),
      );
    });
  });

  group('PlaylistMutations.deletePlaylist', () {
    test(
      'hits /rest/deletePlaylist.view with id; invalidates libraryPlaylists',
      () async {
        final _RouterAdapter adapter = _RouterAdapter(
          <String, FutureOr<ResponseBody> Function(RequestOptions)>{
            '/rest/getPlaylists.view': (_) => _playlistsList(),
            '/rest/deletePlaylist.view': (_) => _emptyOk(),
          },
        );
        final ProviderContainer c = _containerWith(adapter);
        addTearDown(c.dispose);

        c.listen<AsyncValue<List<Playlist>>>(
          libraryPlaylistsProvider,
          (_, _) {},
        );
        await c.read(libraryPlaylistsProvider.future);

        await c
            .read(playlistMutationsProvider.notifier)
            .deletePlaylist('pl-01');

        final RequestOptions req = adapter.lastFor(
          '/rest/deletePlaylist.view',
        )!;
        expect(req.queryParameters['id'], 'pl-01');

        await c.read(libraryPlaylistsProvider.future);
        expect(adapter.countFor('/rest/getPlaylists.view'), 2);
      },
    );

    test('Subsonic code 50 → ForbiddenError', () async {
      final _RouterAdapter adapter = _RouterAdapter(
        <String, FutureOr<ResponseBody> Function(RequestOptions)>{
          '/rest/deletePlaylist.view': (_) =>
              _failed(code: 50, message: 'not authorized'),
        },
      );
      final ProviderContainer c = _containerWith(adapter);
      addTearDown(c.dispose);

      await expectLater(
        c.read(playlistMutationsProvider.notifier).deletePlaylist('pl-01'),
        throwsA(isA<ForbiddenError>()),
      );
    });
  });

  group('PlaylistMutations.addSongs', () {
    test(
      'hits /rest/updatePlaylist.view with playlistId + songIdToAdd multi; '
      'invalidates list + detail',
      () async {
        final _RouterAdapter adapter = _RouterAdapter(
          <String, FutureOr<ResponseBody> Function(RequestOptions)>{
            '/rest/getPlaylists.view': (_) => _playlistsList(),
            '/rest/getPlaylist.view': (_) => _playlistDetail('pl-01'),
            '/rest/updatePlaylist.view': (_) => _emptyOk(),
          },
        );
        final ProviderContainer c = _containerWith(adapter);
        addTearDown(c.dispose);

        c.listen<AsyncValue<List<Playlist>>>(
          libraryPlaylistsProvider,
          (_, _) {},
        );
        c.listen<AsyncValue<Playlist>>(
          libraryPlaylistProvider('pl-01'),
          (_, _) {},
        );
        await c.read(libraryPlaylistsProvider.future);
        await c.read(libraryPlaylistProvider('pl-01').future);

        final int added = await c
            .read(playlistMutationsProvider.notifier)
            .addSongs(
          playlistId: 'pl-01',
          songIds: <String>['a', 'b'],
        );

        // Empty stub playlist → both songs are new → both added.
        expect(added, 2);
        final RequestOptions req = adapter.lastFor(
          '/rest/updatePlaylist.view',
        )!;
        expect(req.queryParameters['playlistId'], 'pl-01');
        expect(_multi(req, 'songIdToAdd'), <String>['a', 'b']);

        await c.read(libraryPlaylistsProvider.future);
        await c.read(libraryPlaylistProvider('pl-01').future);
        expect(adapter.countFor('/rest/getPlaylists.view'), 2);
        // addSongs now does an internal getPlaylist fetch for the
        // dedupe filter, so the per-test count is:
        //   prime (1) + addSongs internal (1) + post-invalidate refetch (1) = 3
        expect(adapter.countFor('/rest/getPlaylist.view'), 3);
      },
    );

    test(
      'all songs already in playlist → 0 added, no updatePlaylist call',
      () async {
        final _RouterAdapter adapter = _RouterAdapter(
          <String, FutureOr<ResponseBody> Function(RequestOptions)>{
            '/rest/getPlaylist.view': (_) => _ok(<String, dynamic>{
              'playlist': <String, dynamic>{
                'id': 'pl-01',
                'name': 'Morning Coffee',
                'songCount': 2,
                'duration': 0,
                'owner': 'phone',
                'public': false,
                'entry': <Map<String, dynamic>>[
                  <String, dynamic>{'id': 'a', 'title': 'A'},
                  <String, dynamic>{'id': 'b', 'title': 'B'},
                ],
              },
            }),
            '/rest/updatePlaylist.view': (_) => _emptyOk(),
          },
        );
        final ProviderContainer c = _containerWith(adapter);
        addTearDown(c.dispose);

        final int added = await c
            .read(playlistMutationsProvider.notifier)
            .addSongs(
          playlistId: 'pl-01',
          songIds: <String>['a', 'b'],
        );

        expect(added, 0);
        expect(adapter.countFor('/rest/updatePlaylist.view'), 0);
      },
    );

    test(
      'partial duplicates → only the new songs go to songIdToAdd',
      () async {
        final _RouterAdapter adapter = _RouterAdapter(
          <String, FutureOr<ResponseBody> Function(RequestOptions)>{
            '/rest/getPlaylist.view': (_) => _ok(<String, dynamic>{
              'playlist': <String, dynamic>{
                'id': 'pl-01',
                'name': 'Morning Coffee',
                'songCount': 1,
                'duration': 0,
                'owner': 'phone',
                'public': false,
                'entry': <Map<String, dynamic>>[
                  <String, dynamic>{'id': 'a', 'title': 'A'},
                ],
              },
            }),
            '/rest/updatePlaylist.view': (_) => _emptyOk(),
          },
        );
        final ProviderContainer c = _containerWith(adapter);
        addTearDown(c.dispose);

        final int added = await c
            .read(playlistMutationsProvider.notifier)
            .addSongs(
          playlistId: 'pl-01',
          songIds: <String>['a', 'b', 'c'],
        );

        expect(added, 2);
        final RequestOptions req = adapter.lastFor(
          '/rest/updatePlaylist.view',
        )!;
        // 'a' already in → filtered out; 'b' and 'c' added in order.
        expect(_multi(req, 'songIdToAdd'), <String>['b', 'c']);
      },
    );
  });

  group('PlaylistMutations.removeSongsAtIndices', () {
    test(
      'sends songIndexToRemove descending so earlier removes do not shift',
      () async {
        final _RouterAdapter adapter = _RouterAdapter(
          <String, FutureOr<ResponseBody> Function(RequestOptions)>{
            '/rest/getPlaylists.view': (_) => _playlistsList(),
            '/rest/getPlaylist.view': (_) => _playlistDetail('pl-01'),
            '/rest/updatePlaylist.view': (_) => _emptyOk(),
          },
        );
        final ProviderContainer c = _containerWith(adapter);
        addTearDown(c.dispose);

        c.listen<AsyncValue<List<Playlist>>>(
          libraryPlaylistsProvider,
          (_, _) {},
        );
        c.listen<AsyncValue<Playlist>>(
          libraryPlaylistProvider('pl-01'),
          (_, _) {},
        );
        await c.read(libraryPlaylistsProvider.future);
        await c.read(libraryPlaylistProvider('pl-01').future);

        await c
            .read(playlistMutationsProvider.notifier)
            .removeSongsAtIndices(
          playlistId: 'pl-01',
          indices: <int>[1, 3, 5],
        );

        final RequestOptions req = adapter.lastFor(
          '/rest/updatePlaylist.view',
        )!;
        expect(req.queryParameters['playlistId'], 'pl-01');
        expect(_multi(req, 'songIndexToRemove'), <String>['5', '3', '1']);

        await c.read(libraryPlaylistsProvider.future);
        await c.read(libraryPlaylistProvider('pl-01').future);
        expect(adapter.countFor('/rest/getPlaylist.view'), 2);
      },
    );

    test('empty indices list is a no-op (no network call)', () async {
      final _RouterAdapter adapter = _RouterAdapter(
        <String, FutureOr<ResponseBody> Function(RequestOptions)>{
          '/rest/updatePlaylist.view': (_) => _emptyOk(),
        },
      );
      final ProviderContainer c = _containerWith(adapter);
      addTearDown(c.dispose);

      await c
          .read(playlistMutationsProvider.notifier)
          .removeSongsAtIndices(
        playlistId: 'pl-01',
        indices: const <int>[],
      );

      expect(adapter.countFor('/rest/updatePlaylist.view'), 0);
    });
  });

  group('PlaylistMutations.reorder', () {
    test(
      'single updatePlaylist call: songIndexToRemove covers every index '
      '+ songIdToAdd in new order',
      () async {
        final _RouterAdapter adapter = _RouterAdapter(
          <String, FutureOr<ResponseBody> Function(RequestOptions)>{
            '/rest/getPlaylists.view': (_) => _playlistsList(),
            '/rest/getPlaylist.view': (_) => _playlistDetail('pl-01'),
            '/rest/updatePlaylist.view': (_) => _emptyOk(),
          },
        );
        final ProviderContainer c = _containerWith(adapter);
        addTearDown(c.dispose);

        c.listen<AsyncValue<List<Playlist>>>(
          libraryPlaylistsProvider,
          (_, _) {},
        );
        c.listen<AsyncValue<Playlist>>(
          libraryPlaylistProvider('pl-01'),
          (_, _) {},
        );
        await c.read(libraryPlaylistsProvider.future);
        await c.read(libraryPlaylistProvider('pl-01').future);

        await c.read(playlistMutationsProvider.notifier).reorder(
          playlistId: 'pl-01',
          newSongIdOrder: <String>['c', 'a', 'b'],
        );

        expect(adapter.countFor('/rest/updatePlaylist.view'), 1);
        final RequestOptions req = adapter.lastFor(
          '/rest/updatePlaylist.view',
        )!;
        expect(req.queryParameters['playlistId'], 'pl-01');
        expect(
          _multi(req, 'songIndexToRemove'),
          <String>['2', '1', '0'],
        );
        expect(_multi(req, 'songIdToAdd'), <String>['c', 'a', 'b']);

        await c.read(libraryPlaylistsProvider.future);
        await c.read(libraryPlaylistProvider('pl-01').future);
        expect(adapter.countFor('/rest/getPlaylist.view'), 2);
      },
    );

    test('empty newSongIdOrder is a no-op', () async {
      final _RouterAdapter adapter = _RouterAdapter(
        <String, FutureOr<ResponseBody> Function(RequestOptions)>{
          '/rest/updatePlaylist.view': (_) => _emptyOk(),
        },
      );
      final ProviderContainer c = _containerWith(adapter);
      addTearDown(c.dispose);

      await c.read(playlistMutationsProvider.notifier).reorder(
        playlistId: 'pl-01',
        newSongIdOrder: const <String>[],
      );

      expect(adapter.countFor('/rest/updatePlaylist.view'), 0);
    });
  });

  // ---------------------------------------------------------------------
  // toggleFavourite — three branches: lazy-create, add, remove.
  // ---------------------------------------------------------------------
  group('PlaylistMutations.toggleFavourite', () {
    const Song song = Song(id: 'so-1', title: 'A');

    test(
      'no Favourites playlist yet → lazy-creates with the song',
      () async {
        final _RouterAdapter adapter = _RouterAdapter(
          <String, FutureOr<ResponseBody> Function(RequestOptions)>{
            '/rest/createPlaylist.view': (_) => _ok(<String, dynamic>{
              'playlist': <String, dynamic>{
                'id': 'fav-1',
                'name': 'Favourites',
                'songCount': 1,
                'duration': 0,
                'owner': 'phone',
                'public': false,
                'entry': <Map<String, dynamic>>[],
              },
            }),
          },
        );
        final ProviderContainer c = ProviderContainer(
          overrides: <Override>[
            subsonicDioClientProvider.overrideWith(
              (Ref<AsyncValue<Dio>> ref) async {
                final Dio dio = Dio(
                  BaseOptions(baseUrl: 'http://navi.test'),
                );
                dio.httpClientAdapter = adapter;
                return dio;
              },
            ),
            favouritesPlaylistProvider.overrideWith(
              (FavouritesPlaylistRef ref) async => null,
            ),
          ],
        );
        addTearDown(c.dispose);

        await c
            .read(playlistMutationsProvider.notifier)
            .toggleFavourite(song);

        final RequestOptions req =
            adapter.lastFor('/rest/createPlaylist.view')!;
        expect(req.queryParameters['name'], 'Favourites');
        expect(_multi(req, 'songId'), <String>['so-1']);
      },
    );

    test(
      'Favourites exists and song is not in it → addSongs path',
      () async {
        const Playlist favPlaylist = Playlist(
          id: 'fav-1',
          name: 'Favourites',
          owner: 'phone',
          songCount: 0,
        );
        const Playlist favDetail = Playlist(
          id: 'fav-1',
          name: 'Favourites',
          owner: 'phone',
          songCount: 0,
          entry: <Song>[],
        );

        final _RouterAdapter adapter = _RouterAdapter(
          <String, FutureOr<ResponseBody> Function(RequestOptions)>{
            '/rest/getPlaylist.view': (_) => _ok(<String, dynamic>{
              'playlist': <String, dynamic>{
                'id': 'fav-1',
                'name': 'Favourites',
                'songCount': 0,
                'duration': 0,
                'owner': 'phone',
                'public': false,
                'entry': <Map<String, dynamic>>[],
              },
            }),
            '/rest/updatePlaylist.view': (_) => _emptyOk(),
          },
        );
        final ProviderContainer c = ProviderContainer(
          overrides: <Override>[
            subsonicDioClientProvider.overrideWith(
              (Ref<AsyncValue<Dio>> ref) async {
                final Dio dio = Dio(
                  BaseOptions(baseUrl: 'http://navi.test'),
                );
                dio.httpClientAdapter = adapter;
                return dio;
              },
            ),
            favouritesPlaylistProvider.overrideWith(
              (FavouritesPlaylistRef ref) async => favPlaylist,
            ),
            libraryPlaylistProvider('fav-1').overrideWith(
              (Ref<AsyncValue<Playlist>> ref) async => favDetail,
            ),
          ],
        );
        addTearDown(c.dispose);

        await c
            .read(playlistMutationsProvider.notifier)
            .toggleFavourite(song);

        final RequestOptions req =
            adapter.lastFor('/rest/updatePlaylist.view')!;
        expect(req.queryParameters['playlistId'], 'fav-1');
        expect(_multi(req, 'songIdToAdd'), <String>['so-1']);
        // Not the remove path.
        expect(req.queryParameters.containsKey('songIndexToRemove'), isFalse);
      },
    );

    test(
      'Favourites exists and song already in it → removeSongsAtIndices path',
      () async {
        const Playlist favPlaylist = Playlist(
          id: 'fav-1',
          name: 'Favourites',
          owner: 'phone',
          songCount: 2,
        );
        const Playlist favDetail = Playlist(
          id: 'fav-1',
          name: 'Favourites',
          owner: 'phone',
          songCount: 2,
          entry: <Song>[
            Song(id: 'so-x', title: 'X'),
            Song(id: 'so-1', title: 'A'),
          ],
        );

        final _RouterAdapter adapter = _RouterAdapter(
          <String, FutureOr<ResponseBody> Function(RequestOptions)>{
            '/rest/updatePlaylist.view': (_) => _emptyOk(),
          },
        );
        final ProviderContainer c = ProviderContainer(
          overrides: <Override>[
            subsonicDioClientProvider.overrideWith(
              (Ref<AsyncValue<Dio>> ref) async {
                final Dio dio = Dio(
                  BaseOptions(baseUrl: 'http://navi.test'),
                );
                dio.httpClientAdapter = adapter;
                return dio;
              },
            ),
            favouritesPlaylistProvider.overrideWith(
              (FavouritesPlaylistRef ref) async => favPlaylist,
            ),
            libraryPlaylistProvider('fav-1').overrideWith(
              (Ref<AsyncValue<Playlist>> ref) async => favDetail,
            ),
          ],
        );
        addTearDown(c.dispose);

        await c
            .read(playlistMutationsProvider.notifier)
            .toggleFavourite(song);

        final RequestOptions req =
            adapter.lastFor('/rest/updatePlaylist.view')!;
        expect(req.queryParameters['playlistId'], 'fav-1');
        // 'so-1' is at index 1 in favDetail.entry.
        expect(_multi(req, 'songIndexToRemove'), <String>['1']);
        expect(req.queryParameters.containsKey('songIdToAdd'), isFalse);
      },
    );
  });
}
