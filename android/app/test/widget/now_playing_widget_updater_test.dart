import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heerr/player/heerr_audio_handler.dart';
import 'package:heerr/widget/now_playing_widget.dart';
import 'package:mocktail/mocktail.dart';

class _MockHomeWidgetClient extends Mock implements HomeWidgetClient {}

class _MockTintExtractor extends Mock implements WidgetTintExtractor {}

class _MockArtCache extends Mock implements WidgetArtCache {}

void main() {
  late _MockHomeWidgetClient client;
  late NowPlayingWidgetUpdater updater;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://fallback'));
  });

  setUp(() {
    client = _MockHomeWidgetClient();
    when(() => client.saveString(any(), any())).thenAnswer((_) async {});
    when(() => client.saveBool(any(), any())).thenAnswer((_) async {});
    when(() => client.update()).thenAnswer((_) async {});
    updater = NowPlayingWidgetUpdater(client: client);
  });

  PlayerSnapshot snap(
    MediaItem? item, {
    bool playing = false,
    Duration position = Duration.zero,
  }) =>
      PlayerSnapshot(
        item: item,
        state: PlaybackState(playing: playing, updatePosition: position),
      );

  MediaItem track(String id, {Duration? duration, Uri? art}) =>
      MediaItem(id: id, title: 'T', artist: 'A', duration: duration, artUri: art);

  group('NowPlayingWidgetUpdater (#20)', () {
    test('push with a playing track writes fields + triggers update', () async {
      await updater.push(snap(
        const MediaItem(id: 'song://1', title: 'Hello', artist: 'Adele'),
        playing: true,
      ));

      verify(() => client.saveBool(kNpKeyHasTrack, true)).called(1);
      verify(() => client.saveString(kNpKeyTitle, 'Hello')).called(1);
      verify(() => client.saveString(kNpKeyArtist, 'Adele')).called(1);
      verify(() => client.saveBool(kNpKeyPlaying, true)).called(1);
      verify(() => client.update()).called(1);
    });

    test('push paused writes playing=false', () async {
      await updater.push(
        snap(const MediaItem(id: 'a', title: 'T', artist: 'A'), playing: false),
      );

      verify(() => client.saveBool(kNpKeyPlaying, false)).called(1);
    });

    test('null artist falls back to empty string', () async {
      await updater.push(snap(const MediaItem(id: 'a', title: 'T')));

      verify(() => client.saveString(kNpKeyArtist, '')).called(1);
    });

    test('push with null item clears the widget', () async {
      await updater.push(snap(null));

      verify(() => client.saveBool(kNpKeyHasTrack, false)).called(1);
      verify(() => client.saveString(kNpKeyTitle, '')).called(1);
      verify(() => client.saveString(kNpKeyTintArgb, '')).called(1);
      verify(() => client.update()).called(1);
    });

    test('a client error never throws out of push', () async {
      when(() => client.update()).thenThrow(Exception('platform missing'));

      await expectLater(
        updater.push(snap(const MediaItem(id: 'a', title: 'T'))),
        completes,
      );
    });
  });

  group('NowPlayingWidgetUpdater tint (#20)', () {
    late _MockTintExtractor tint;
    late NowPlayingWidgetUpdater tintUpdater;

    setUp(() {
      tint = _MockTintExtractor();
      tintUpdater =
          NowPlayingWidgetUpdater(client: client, tintExtractor: tint);
    });

    test('writes the cover tint for an http artUri, once per track', () async {
      when(() => tint.argbFor(any())).thenAnswer((_) async => -12345678);
      final MediaItem t = track('s1', art: Uri.parse('https://h/c?id=1'));

      await tintUpdater.push(snap(t, playing: true));
      await tintUpdater.push(snap(t, playing: false));

      verify(() => tint.argbFor(Uri.parse('https://h/c?id=1'))).called(1);
      verify(() => client.saveString(kNpKeyTintArgb, '-12345678'))
          .called(greaterThanOrEqualTo(1));
    });

    test('non-http artUri writes empty tint and skips extraction', () async {
      await tintUpdater.push(
        snap(track('s1', art: Uri.parse('android.resource://x/y'))),
      );

      verifyNever(() => tint.argbFor(any()));
      verify(() => client.saveString(kNpKeyTintArgb, '')).called(1);
    });

    test('null extraction result writes empty tint', () async {
      when(() => tint.argbFor(any())).thenAnswer((_) async => null);

      await tintUpdater
          .push(snap(track('s1', art: Uri.parse('https://h/c?id=1'))));

      verify(() => client.saveString(kNpKeyTintArgb, '')).called(1);
    });
  });

  group('NowPlayingWidgetUpdater cover thumbnail (#20)', () {
    late _MockArtCache art;
    late NowPlayingWidgetUpdater artUpdater;

    setUp(() {
      art = _MockArtCache();
      artUpdater = NowPlayingWidgetUpdater(client: client, artCache: art);
    });

    test('caches the cover for an http artUri and saves its path', () async {
      when(() => art.cache(any())).thenAnswer((_) async => '/data/art.png');

      await artUpdater
          .push(snap(track('s1', art: Uri.parse('https://h/c?id=1'))));

      verify(() => art.cache(Uri.parse('https://h/c?id=1'))).called(1);
      verify(() => client.saveString(kNpKeyArtPath, '/data/art.png')).called(1);
    });

    test('does not re-download for the same track', () async {
      when(() => art.cache(any())).thenAnswer((_) async => '/data/art.png');
      final MediaItem same = track('s1', art: Uri.parse('https://h/c?id=1'));

      await artUpdater.push(snap(same, playing: true));
      await artUpdater.push(snap(same, playing: false));

      verify(() => art.cache(any())).called(1);
    });

    test('coalesces concurrent fetches for the same track', () async {
      final Completer<String?> pending = Completer<String?>();
      when(() => art.cache(any())).thenAnswer((_) => pending.future);

      final Future<void> a =
          artUpdater.push(snap(track('s1', art: Uri.parse('https://h/c?id=1'))));
      final Future<void> b =
          artUpdater.push(snap(track('s1', art: Uri.parse('https://h/c?id=1'))));
      pending.complete('/data/art.png');
      await Future.wait(<Future<void>>[a, b]);

      verify(() => art.cache(any())).called(1);
    });

    test('non-http artUri saves empty path and skips the cache', () async {
      await artUpdater.push(
        snap(track('s1', art: Uri.parse('android.resource://x/y'))),
      );

      verifyNever(() => art.cache(any()));
      verify(() => client.saveString(kNpKeyArtPath, '')).called(1);
    });

    test('null item clears the art path', () async {
      await artUpdater.push(snap(null));

      verify(() => client.saveString(kNpKeyArtPath, '')).called(1);
    });
  });
}
