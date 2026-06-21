import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heerr/player/heerr_audio_handler.dart';
import 'package:heerr/widget/now_playing_widget.dart';
import 'package:mocktail/mocktail.dart';

class _MockHomeWidgetClient extends Mock implements HomeWidgetClient {}

void main() {
  late _MockHomeWidgetClient client;
  late NowPlayingWidgetUpdater updater;

  setUp(() {
    client = _MockHomeWidgetClient();
    when(() => client.saveString(any(), any())).thenAnswer((_) async {});
    when(() => client.saveBool(any(), any())).thenAnswer((_) async {});
    when(() => client.update()).thenAnswer((_) async {});
    updater = NowPlayingWidgetUpdater(client: client);
  });

  PlayerSnapshot snap(MediaItem? item, {bool playing = false}) =>
      PlayerSnapshot(item: item, state: PlaybackState(playing: playing));

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
}
