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
    registerFallbackValue(<AudioSource>[]);
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

  group('addQueueItems (#35)', () {
    const MediaItem a = MediaItem(id: 'https://x/a', title: 'A');
    const MediaItem b = MediaItem(id: 'https://x/b', title: 'B');
    const MediaItem c = MediaItem(id: 'https://x/c', title: 'C');

    setUp(() {
      when(() => player.addAudioSources(any())).thenAnswer((_) async {});
    });

    test('appends the batch to the queue and hands it to the player',
        () async {
      await handler.addQueueItems(const <MediaItem>[a, b]);
      expect(handler.queue.value, const <MediaItem>[a, b]);
      final List<AudioSource> sources = verify(
        () => player.addAudioSources(captureAny()),
      ).captured.single as List<AudioSource>;
      expect(sources, hasLength(2));
    });

    test('appends behind existing queue items, preserving order', () async {
      await handler.addQueueItems(const <MediaItem>[a]);
      await handler.addQueueItems(const <MediaItem>[b, c]);
      expect(handler.queue.value, const <MediaItem>[a, b, c]);
    });

    test('empty batch is a no-op', () async {
      await handler.addQueueItems(const <MediaItem>[]);
      expect(handler.queue.value, isEmpty);
      verifyNever(() => player.addAudioSources(any()));
    });
  });

  group('removeQueueItemAt / moveQueueItem (#35)', () {
    const MediaItem a = MediaItem(id: 'https://x/a', title: 'A');
    const MediaItem b = MediaItem(id: 'https://x/b', title: 'B');
    const MediaItem c = MediaItem(id: 'https://x/c', title: 'C');

    setUp(() {
      when(() => player.addAudioSources(any())).thenAnswer((_) async {});
      when(() => player.removeAudioSourceAt(any())).thenAnswer((_) async {});
      when(() => player.moveAudioSource(any(), any()))
          .thenAnswer((_) async {});
      when(() => player.currentIndex).thenReturn(0);
    });

    Future<void> seed() =>
        handler.addQueueItems(const <MediaItem>[a, b, c]);

    test('remove drops the entry and forwards the index to the player',
        () async {
      await seed();
      await handler.removeQueueItemAt(1);
      expect(handler.queue.value, const <MediaItem>[a, c]);
      verify(() => player.removeAudioSourceAt(1)).called(1);
    });

    test('remove out of range is a no-op', () async {
      await seed();
      await handler.removeQueueItemAt(3);
      await handler.removeQueueItemAt(-1);
      expect(handler.queue.value, const <MediaItem>[a, b, c]);
      verifyNever(() => player.removeAudioSourceAt(any()));
    });

    test('remove re-broadcasts the item at the player index', () async {
      await seed();
      // Playing index 0 (a); removing it leaves the player pointing at
      // index 0 of the new list (b) without a currentIndexStream emit.
      await handler.removeQueueItemAt(0);
      expect(handler.mediaItem.value, b);
    });

    test('removing the last remaining item clears mediaItem', () async {
      when(() => player.currentIndex).thenReturn(null);
      await handler.addQueueItems(const <MediaItem>[a]);
      await handler.removeQueueItemAt(0);
      expect(handler.queue.value, isEmpty);
      expect(handler.mediaItem.value, isNull);
    });

    test('move reorders with remove-then-insert semantics', () async {
      await seed();
      await handler.moveQueueItem(0, 2);
      expect(handler.queue.value, const <MediaItem>[b, c, a]);
      verify(() => player.moveAudioSource(0, 2)).called(1);
    });

    test('move to same index or out of range is a no-op', () async {
      await seed();
      await handler.moveQueueItem(1, 1);
      await handler.moveQueueItem(-1, 2);
      await handler.moveQueueItem(0, 3);
      expect(handler.queue.value, const <MediaItem>[a, b, c]);
      verifyNever(() => player.moveAudioSource(any(), any()));
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
