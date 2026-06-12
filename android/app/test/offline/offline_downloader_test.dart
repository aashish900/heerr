import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/offline/offline_downloader.dart';
import 'package:heerr/offline/offline_manifest.dart';
import 'package:heerr/offline/offline_paths.dart';
import 'package:heerr/providers/settings.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.responder);
  final FutureOr<ResponseBody> Function(RequestOptions options) responder;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    requests.add(options);
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_StubAdapter adapter) {
  final Dio dio = Dio();
  dio.httpClientAdapter = adapter;
  return dio;
}

ResponseBody _bodyOfBytes(
  List<int> bytes, {
  int statusCode = 200,
}) {
  return ResponseBody.fromBytes(
    bytes,
    statusCode,
    headers: <String, List<String>>{
      'content-type': <String>['audio/mpeg'],
      'content-length': <String>[bytes.length.toString()],
    },
  );
}

SettingsValue _settings({String url = 'http://navi:4533', String? user = 'me', String? pass = 'pw'}) {
  return (
    backendBaseUrl: null,
    bearerToken: null,
    navidromeBaseUrl: url,
    navidromeUsername: user,
    navidromePassword: pass,
    offlineEnabled: true,
    offlineSyncAll: false,
    offlineWifiOnly: true,
    offlinePollIntervalMin: 15,
  );
}

void main() {
  late Directory tmp;
  late OfflinePaths paths;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('heerr-dl-');
    paths = OfflinePaths(tmp);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('downloadSong', () {
    test('happy path: writes file, verifies size, returns ready entry',
        () async {
      final List<int> payload = List<int>.generate(1024, (int i) => i % 256);
      final _StubAdapter adapter = _StubAdapter(
        (RequestOptions o) => _bodyOfBytes(payload),
      );
      final SettingsValue settings = _settings();
      const Song song = Song(
        id: 'so-1',
        title: 't',
        suffix: 'mp3',
        size: 1024,
      );

      final OfflineSongEntry entry = await downloadSong(
        song: song,
        settings: settings,
        paths: paths,
        downloadDio: _dio(adapter),
      );

      expect(entry.state, OfflineSongState.ready);
      expect(entry.size, 1024);
      expect(entry.suffix, 'mp3');
      expect(entry.localPath, isNotNull);
      expect(entry.downloadedAt, isNotNull);

      final File target = File(entry.localPath!);
      expect(await target.exists(), isTrue);
      expect(await target.length(), 1024);

      // .partial cleaned up.
      final File partial = File('${entry.localPath}.partial');
      expect(await partial.exists(), isFalse);

      // The hit URL is the Subsonic stream.view endpoint with our creds in.
      expect(adapter.requests, hasLength(1));
      final RequestOptions r = adapter.requests.single;
      expect(r.uri.path, '/rest/stream.view');
      expect(r.uri.queryParameters['id'], 'so-1');
      expect(r.uri.queryParameters['u'], 'me');
    });

    test('happy path: missing song.size is accepted', () async {
      final List<int> payload = List<int>.filled(512, 0);
      final _StubAdapter adapter = _StubAdapter(
        (RequestOptions o) => _bodyOfBytes(payload),
      );

      final OfflineSongEntry entry = await downloadSong(
        song: const Song(id: 'so-2', title: 't', suffix: 'mp3'),
        settings: _settings(),
        paths: paths,
        downloadDio: _dio(adapter),
      );

      expect(entry.state, OfflineSongState.ready);
      expect(entry.size, 512);
    });

    test('size mismatch: returns failed + deletes the file', () async {
      final List<int> payload = List<int>.filled(100, 0);
      final _StubAdapter adapter = _StubAdapter(
        (RequestOptions o) => _bodyOfBytes(payload),
      );

      final OfflineSongEntry entry = await downloadSong(
        song: const Song(id: 'so-3', title: 't', suffix: 'mp3', size: 200),
        settings: _settings(),
        paths: paths,
        downloadDio: _dio(adapter),
      );

      expect(entry.state, OfflineSongState.failed);
      expect(entry.lastError, contains('size mismatch'));
      expect(entry.lastError, contains('200'));
      expect(entry.lastError, contains('100'));

      // No leftover file or .partial.
      final Directory songsDir = paths.songsDir(_settings())!;
      if (await songsDir.exists()) {
        final List<FileSystemEntity> list = await songsDir.list().toList();
        expect(list, isEmpty);
      }
    });

    test('HTTP error: returns failed with ApiError-mapped message', () async {
      final _StubAdapter adapter = _StubAdapter(
        (RequestOptions o) => _bodyOfBytes(<int>[], statusCode: 404),
      );

      final OfflineSongEntry entry = await downloadSong(
        song: const Song(id: 'so-4', title: 't', suffix: 'mp3'),
        settings: _settings(),
        paths: paths,
        downloadDio: _dio(adapter),
      );

      expect(entry.state, OfflineSongState.failed);
      expect(entry.lastError, isNotNull);
      // ApiError mapping for 404 → NotFoundError ("not found" or detail).
      expect(entry.lastError!.toLowerCase(), contains('not found'));

      // .partial cleaned up.
      final Directory songsDir = paths.songsDir(_settings())!;
      if (await songsDir.exists()) {
        final List<FileSystemEntity> list = await songsDir.list().toList();
        expect(list, isEmpty);
      }
    });

    test('connection error: returns failed with NetworkError-mapped message',
        () async {
      final _StubAdapter adapter = _StubAdapter(
        (RequestOptions o) => throw DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
          error: 'no route to host',
        ),
      );

      final OfflineSongEntry entry = await downloadSong(
        song: const Song(id: 'so-5', title: 't', suffix: 'mp3'),
        settings: _settings(),
        paths: paths,
        downloadDio: _dio(adapter),
      );

      expect(entry.state, OfflineSongState.failed);
      expect(entry.lastError, isNotNull);
      expect(entry.lastError!.toLowerCase(), contains('tailscale'));
    });

    test('missing Navidrome creds: returns failed without touching disk',
        () async {
      // adapter that throws if hit — proves we short-circuit.
      final _StubAdapter adapter = _StubAdapter(
        (RequestOptions o) => throw StateError('should not hit the network'),
      );

      final OfflineSongEntry entry = await downloadSong(
        song: const Song(id: 'so-6', title: 't', suffix: 'mp3'),
        settings: _settings(user: null),
        paths: paths,
        downloadDio: _dio(adapter),
      );

      expect(entry.state, OfflineSongState.failed);
      expect(entry.lastError, contains('creds'));
    });

    test('default suffix mp3 when Song.suffix is null', () async {
      final List<int> payload = List<int>.filled(128, 0);
      final _StubAdapter adapter = _StubAdapter(
        (RequestOptions o) => _bodyOfBytes(payload),
      );

      final OfflineSongEntry entry = await downloadSong(
        song: const Song(id: 'so-7', title: 't'),
        settings: _settings(),
        paths: paths,
        downloadDio: _dio(adapter),
      );

      expect(entry.state, OfflineSongState.ready);
      expect(entry.localPath, endsWith('so-7.mp3'));
      expect(entry.suffix, 'mp3');
    });
  });
}
