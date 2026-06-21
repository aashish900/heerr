import 'dart:async';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/subsonic_client.dart';
import 'package:heerr/models/job_view.dart';
import 'package:heerr/models/queue_response.dart';
import 'package:heerr/models/subsonic/playlist.dart';
import 'package:heerr/player/heerr_audio_handler.dart';
import 'package:heerr/player/player_provider.dart';
import 'package:heerr/providers/library/library_playlists.dart';
import 'package:heerr/providers/queue.dart';
import 'package:heerr/providers/server_creds.dart';
import 'package:heerr/screens/player/now_playing_screen.dart';
import 'package:heerr/utils/palette.dart';

class _StubQueue extends Queue {
  @override
  Future<QueueResponse> build() async =>
      const QueueResponse(active: <JobView>[], recent: <JobView>[]);

  @override
  void pause() {}

  @override
  Future<void> resume() async {}
}

class _NoopAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"subsonic-response":{"status":"ok"}}',
      200,
      headers: <String, List<String>>{
        'content-type': <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

PlayerSnapshot _snap(MediaItem item) =>
    PlayerSnapshot(item: item, state: PlaybackState(playing: true));

// MediaItem.id is the stream URL; the Subsonic song id rides in extras
// (mirrors song_to_media_item.dart), which is what songFromMediaItem reads.
MediaItem _item() => const MediaItem(
      id: 'http://stream/song-1',
      title: 'Track A',
      artist: 'Artist A',
      extras: <String, dynamic>{'subsonicId': 'song-1'},
    );

Widget _wrap({MediaItem? item}) {
  final MediaItem playing = item ?? _item();
  return ProviderScope(
    overrides: <Override>[
      subsonicDioClientProvider.overrideWith(
        (Ref<AsyncValue<Dio>> ref) async {
          final Dio dio = Dio(BaseOptions(baseUrl: 'http://navi.test'));
          dio.httpClientAdapter = _NoopAdapter();
          return dio;
        },
      ),
      playerSnapshotProvider.overrideWith(
        (Ref<AsyncValue<PlayerSnapshot>> ref) =>
            Stream<PlayerSnapshot>.value(_snap(playing)),
      ),
      playerQueueProvider.overrideWith(
        (Ref<AsyncValue<List<MediaItem>>> ref) =>
            Stream<List<MediaItem>>.value(<MediaItem>[]),
      ),
      currentMediaItemProvider.overrideWith(
        (Ref<AsyncValue<MediaItem?>> ref) =>
            Stream<MediaItem?>.value(playing),
      ),
      queueProvider.overrideWith(_StubQueue.new),
      libraryPlaylistsProvider.overrideWith(
        (Ref<AsyncValue<List<Playlist>>> ref) async => const <Playlist>[],
      ),
      serverCredsProvider.overrideWith(
        (Ref<ServerCreds> ref) => (
          navidromeBaseUrl: 'http://navi.test',
          navidromeUsername: 'tester',
          navidromePassword: 'pw',
        ),
      ),
    ],
    child: const MaterialApp(home: NowPlayingScreen()),
  );
}

void main() {
  setUp(() {
    paletteExtractorOverride = (Uri? _) async => null;
  });
  tearDown(() {
    paletteExtractorOverride = dominantColorFor;
  });

  testWidgets('overflow menu exposes an "Add to playlist" item',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('now-playing-overflow')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('now-playing-add-to-playlist')), findsOneWidget);
    expect(find.text('Add to playlist'), findsOneWidget);
    // Sleep timer still present alongside it.
    expect(find.text('Sleep timer'), findsOneWidget);
  });

  testWidgets('tapping "Add to playlist" opens the AddToPlaylistSheet',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('now-playing-overflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('now-playing-add-to-playlist')));
    await tester.pumpAndSettle();

    // Sheet for the single playing track.
    expect(find.text('Add 1 song to playlist'), findsOneWidget);
    expect(find.text('Create new playlist…'), findsOneWidget);
  });

  testWidgets(
      'non-Subsonic track (no subsonicId) shows a snackbar instead of the sheet',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      item: const MediaItem(id: 'http://stream/x', title: 'T', artist: 'A'),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('now-playing-overflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('now-playing-add-to-playlist')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Add 1 song to playlist'), findsNothing);
    expect(find.text("Can't add this track to a playlist"), findsOneWidget);
  });
}
