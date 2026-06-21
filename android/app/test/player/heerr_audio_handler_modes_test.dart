import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';

import 'package:heerr/player/heerr_audio_handler.dart';

class _MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  late _MockAudioPlayer player;
  late HeerrAudioHandler handler;

  setUpAll(() {
    registerFallbackValue(LoopMode.off);
  });

  setUp(() {
    player = _MockAudioPlayer();
    // The constructor wires these two streams via _wirePlayerStreams; stub
    // them so the handler can be built without platform channels.
    when(() => player.playbackEventStream)
        .thenAnswer((_) => const Stream<PlaybackEvent>.empty());
    when(() => player.currentIndexStream)
        .thenAnswer((_) => const Stream<int?>.empty());
    when(() => player.setLoopMode(any())).thenAnswer((_) async {});
    when(() => player.setShuffleModeEnabled(any())).thenAnswer((_) async {});
    handler = HeerrAudioHandler(player: player);
  });

  group('setRepeatMode', () {
    test('none → LoopMode.off and broadcasts none', () async {
      await handler.setRepeatMode(AudioServiceRepeatMode.none);
      verify(() => player.setLoopMode(LoopMode.off)).called(1);
      expect(handler.playbackState.value.repeatMode,
          AudioServiceRepeatMode.none);
    });

    test('one → LoopMode.one and broadcasts one', () async {
      await handler.setRepeatMode(AudioServiceRepeatMode.one);
      verify(() => player.setLoopMode(LoopMode.one)).called(1);
      expect(handler.playbackState.value.repeatMode,
          AudioServiceRepeatMode.one);
    });

    test('all → LoopMode.all and broadcasts all', () async {
      await handler.setRepeatMode(AudioServiceRepeatMode.all);
      verify(() => player.setLoopMode(LoopMode.all)).called(1);
      expect(handler.playbackState.value.repeatMode,
          AudioServiceRepeatMode.all);
    });

    test('group → LoopMode.all (mapped like all)', () async {
      await handler.setRepeatMode(AudioServiceRepeatMode.group);
      verify(() => player.setLoopMode(LoopMode.all)).called(1);
      expect(handler.playbackState.value.repeatMode,
          AudioServiceRepeatMode.group);
    });
  });

  group('setShuffleMode', () {
    test('all → enables shuffle and broadcasts all', () async {
      await handler.setShuffleMode(AudioServiceShuffleMode.all);
      verify(() => player.setShuffleModeEnabled(true)).called(1);
      expect(handler.playbackState.value.shuffleMode,
          AudioServiceShuffleMode.all);
    });

    test('none → disables shuffle and broadcasts none', () async {
      await handler.setShuffleMode(AudioServiceShuffleMode.none);
      verify(() => player.setShuffleModeEnabled(false)).called(1);
      expect(handler.playbackState.value.shuffleMode,
          AudioServiceShuffleMode.none);
    });
  });
}
