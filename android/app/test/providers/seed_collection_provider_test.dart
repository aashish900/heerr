import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/subsonic_client.dart';
import 'package:heerr/models/seed_track.dart';
import 'package:heerr/providers/recommendations.dart';
import 'package:heerr/providers/settings.dart';

// Reuses the route-by-path adapter shape from
// test/providers/library/playlist_mutations_test.dart — kept local so this
// test file is self-contained.
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
      return _ok(<String, dynamic>{});
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

ResponseBody _starredSongs(List<Map<String, dynamic>> songs) {
  return _ok(<String, dynamic>{
    'starred2': <String, dynamic>{'song': songs},
  });
}

ResponseBody _emptyStarred() => _starredSongs(<Map<String, dynamic>>[]);

ResponseBody _frequentAlbums(List<Map<String, dynamic>> albums) {
  return _ok(<String, dynamic>{
    'albumList2': <String, dynamic>{'album': albums},
  });
}

ResponseBody _emptyFrequent() => _frequentAlbums(<Map<String, dynamic>>[]);

ResponseBody _playlistsList(List<Map<String, dynamic>> playlists) {
  return _ok(<String, dynamic>{
    'playlists': <String, dynamic>{'playlist': playlists},
  });
}

ResponseBody _playlistDetail({
  required String id,
  required String name,
  required String owner,
  required List<Map<String, dynamic>> entries,
}) {
  return _ok(<String, dynamic>{
    'playlist': <String, dynamic>{
      'id': id,
      'name': name,
      'owner': owner,
      'public': false,
      'songCount': entries.length,
      'duration': 0,
      'entry': entries,
    },
  });
}

const SettingsValue _kSettingsWithUsername = (
  backendBaseUrl: null,
  bearerToken: null,
  navidromeBaseUrl: 'http://navi.test',
  navidromeUsername: 'aashish',
  navidromePassword: 'p',
  offlineEnabled: false,
  offlineSyncAll: false,
  offlineWifiOnly: true,
  offlinePollIntervalMin: 15, offlineChargingOnly: false,
);

ProviderContainer _container(
  _RouterAdapter adapter, {
  SettingsValue? settings,
}) {
  return ProviderContainer(
    overrides: <Override>[
      subsonicDioClientProvider.overrideWith(
        (Ref<AsyncValue<Dio>> ref) async {
          final Dio dio = Dio(BaseOptions(baseUrl: 'http://navi.test'));
          dio.httpClientAdapter = adapter;
          return dio;
        },
      ),
      if (settings != null) settingsProvider.overrideWith(() => _FakeSettings(settings)),
    ],
  );
}

class _FakeSettings extends Settings {
  _FakeSettings(this._value);
  final SettingsValue _value;

  @override
  Future<SettingsValue> build() async => _value;
}

void main() {
  // library_cache (which the playlist providers use via cacheAware) reaches
  // for path_provider on first access. Binding init lets those calls
  // gracefully no-op in test rather than throwing on the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hits getStarred2.view and getAlbumList2 with type=frequent, size=30',
      () async {
    final _RouterAdapter adapter = _RouterAdapter(
      <String, FutureOr<ResponseBody> Function(RequestOptions)>{
        '/rest/getStarred2.view': (_) => _emptyStarred(),
        '/rest/getAlbumList2.view': (_) => _emptyFrequent(),
        '/rest/getPlaylists.view': (_) =>
            _playlistsList(<Map<String, dynamic>>[]),
      },
    );
    final ProviderContainer c =
        _container(adapter, settings: _kSettingsWithUsername);
    addTearDown(c.dispose);

    await c.read(seedCollectionProvider.future);

    expect(adapter.countFor('/rest/getStarred2.view'), 1);
    expect(adapter.countFor('/rest/getAlbumList2.view'), 1);
    final RequestOptions albumReq =
        adapter.lastFor('/rest/getAlbumList2.view')!;
    expect(albumReq.queryParameters['type'], 'frequent');
    expect(albumReq.queryParameters['size'], 30);
  });

  test('parses starred songs and frequent albums into SeedTracks', () async {
    final _RouterAdapter adapter = _RouterAdapter(
      <String, FutureOr<ResponseBody> Function(RequestOptions)>{
        '/rest/getStarred2.view': (_) => _starredSongs(<Map<String, dynamic>>[
              <String, dynamic>{
                'id': 's1',
                'title': 'StarSong',
                'artist': 'StarArtist',
              },
            ]),
        '/rest/getAlbumList2.view': (_) =>
            _frequentAlbums(<Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'a1',
                'name': 'FreqAlbum',
                'artist': 'FreqArtist',
              },
            ]),
      },
    );
    final ProviderContainer c =
        _container(adapter, settings: _kSettingsWithUsername);
    addTearDown(c.dispose);

    final List<SeedTrack> seeds =
        await c.read(seedCollectionProvider.future);
    expect(seeds.map((s) => '${s.title}/${s.artist}').toList(),
        <String>['StarSong/StarArtist', 'FreqAlbum/FreqArtist']);
  });

  test(
      'when both primary sources are empty, falls back to Favourites playlist '
      'entries — exactly the rows tagged as Favourites for the active user',
      () async {
    final _RouterAdapter adapter = _RouterAdapter(
      <String, FutureOr<ResponseBody> Function(RequestOptions)>{
        '/rest/getStarred2.view': (_) => _emptyStarred(),
        '/rest/getAlbumList2.view': (_) => _emptyFrequent(),
        '/rest/getPlaylists.view': (_) => _playlistsList(<Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'pl-fav',
                'name': 'Favourites',
                'owner': 'aashish',
                'songCount': 2,
                'duration': 0,
              },
              <String, dynamic>{
                'id': 'pl-other',
                'name': 'Other',
                'owner': 'aashish',
                'songCount': 0,
                'duration': 0,
              },
            ]),
        '/rest/getPlaylist.view': (_) => _playlistDetail(
              id: 'pl-fav',
              name: 'Favourites',
              owner: 'aashish',
              entries: <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'f1',
                  'title': 'FavTrack1',
                  'artist': 'FavArtist1',
                },
                <String, dynamic>{
                  'id': 'f2',
                  'title': 'FavTrack2',
                  'artist': 'FavArtist2',
                },
              ],
            ),
      },
    );
    final ProviderContainer c =
        _container(adapter, settings: _kSettingsWithUsername);
    addTearDown(c.dispose);

    final List<SeedTrack> seeds =
        await c.read(seedCollectionProvider.future);

    expect(seeds.map((s) => s.title).toList(),
        <String>['FavTrack1', 'FavTrack2']);
    // Favourites fetch path actually fired.
    expect(adapter.countFor('/rest/getPlaylists.view'), 1);
    expect(adapter.countFor('/rest/getPlaylist.view'), 1);
  });

  test('does not hit the Favourites endpoints when primary sources non-empty',
      () async {
    final _RouterAdapter adapter = _RouterAdapter(
      <String, FutureOr<ResponseBody> Function(RequestOptions)>{
        '/rest/getStarred2.view': (_) => _starredSongs(<Map<String, dynamic>>[
              <String, dynamic>{'id': 's1', 'title': 'X', 'artist': 'Y'},
            ]),
        '/rest/getAlbumList2.view': (_) => _emptyFrequent(),
      },
    );
    final ProviderContainer c =
        _container(adapter, settings: _kSettingsWithUsername);
    addTearDown(c.dispose);

    await c.read(seedCollectionProvider.future);
    expect(adapter.countFor('/rest/getPlaylists.view'), 0);
    expect(adapter.countFor('/rest/getPlaylist.view'), 0);
  });

  test(
      'fallback returns [] gracefully when no Favourites playlist exists yet',
      () async {
    final _RouterAdapter adapter = _RouterAdapter(
      <String, FutureOr<ResponseBody> Function(RequestOptions)>{
        '/rest/getStarred2.view': (_) => _emptyStarred(),
        '/rest/getAlbumList2.view': (_) => _emptyFrequent(),
        '/rest/getPlaylists.view': (_) =>
            _playlistsList(<Map<String, dynamic>>[]),
      },
    );
    final ProviderContainer c =
        _container(adapter, settings: _kSettingsWithUsername);
    addTearDown(c.dispose);

    final List<SeedTrack> seeds =
        await c.read(seedCollectionProvider.future);
    expect(seeds, isEmpty);
    expect(adapter.countFor('/rest/getPlaylist.view'), 0);
  });
}
