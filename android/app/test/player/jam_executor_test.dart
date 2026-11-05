import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rxdart/rxdart.dart';

import 'package:heerr/models/jam.dart';
import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/player/heerr_audio_handler.dart';
import 'package:heerr/player/jam_executor.dart';

class _MockHandler extends Mock implements HeerrAudioHandler {}

MediaItem _item(String id) => MediaItem(
  id: 'http://nd/stream?id=$id',
  title: 'T$id',
  extras: <String, dynamic>{'subsonicId': id},
);

Future<MediaItem> _toItem(Song s) async => _item(s.id);

Map<String, dynamic> _song(String id) => Song(id: id, title: 'T$id').toJson();

JamCommand _cmd(String kind, [Map<String, dynamic>? payload]) =>
    JamCommand(id: 1, kind: kind, payload: payload ?? <String, dynamic>{});

void main() {
  late _MockHandler h;
  late BehaviorSubject<List<MediaItem>> queue;

  setUpAll(() {
    registerFallbackValue(<MediaItem>[]);
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    h = _MockHandler();
    queue = BehaviorSubject<List<MediaItem>>.seeded(<MediaItem>[]);
    when(() => h.queue).thenAnswer((_) => queue);
    when(
      () => h.playAll(any(), startIndex: any(named: 'startIndex')),
    ).thenAnswer((_) async {});
    when(() => h.addQueueItems(any())).thenAnswer((_) async {});
    when(() => h.play()).thenAnswer((_) async {});
    when(() => h.pause()).thenAnswer((_) async {});
    when(() => h.skipToNext()).thenAnswer((_) async {});
    when(() => h.skipToPrevious()).thenAnswer((_) async {});
    when(() => h.seek(any())).thenAnswer((_) async {});
  });

  tearDown(() => queue.close());

  test('play_songs builds items and plays from start_index', () async {
    await runJamCommand(
      _cmd('play_songs', <String, dynamic>{
        'songs': <dynamic>[_song('a'), _song('b')],
        'start_index': 1,
      }),
      h,
      _toItem,
    );
    final List<dynamic> args = verify(
      () =>
          h.playAll(captureAny(), startIndex: captureAny(named: 'startIndex')),
    ).captured;
    expect((args[0] as List<MediaItem>).map((MediaItem m) => m.title), <String>[
      'Ta',
      'Tb',
    ]);
    expect(args[1], 1);
  });

  test('play_songs with out-of-range start_index starts at 0', () async {
    await runJamCommand(
      _cmd('play_songs', <String, dynamic>{
        'songs': <dynamic>[_song('a')],
        'start_index': 9,
      }),
      h,
      _toItem,
    );
    verify(() => h.playAll(any(), startIndex: 0)).called(1);
  });

  test('enqueue on empty queue plays', () async {
    await runJamCommand(
      _cmd('enqueue', <String, dynamic>{
        'songs': <dynamic>[_song('a')],
      }),
      h,
      _toItem,
    );
    verify(
      () => h.playAll(any(), startIndex: any(named: 'startIndex')),
    ).called(1);
    verifyNever(() => h.addQueueItems(any()));
  });

  test('enqueue on non-empty queue appends', () async {
    queue.add(<MediaItem>[_item('x')]);
    await runJamCommand(
      _cmd('enqueue', <String, dynamic>{
        'songs': <dynamic>[_song('a')],
      }),
      h,
      _toItem,
    );
    verify(() => h.addQueueItems(any())).called(1);
  });

  test('transport kinds map to handler methods', () async {
    await runJamCommand(_cmd('play'), h, _toItem);
    await runJamCommand(_cmd('pause'), h, _toItem);
    await runJamCommand(_cmd('next'), h, _toItem);
    await runJamCommand(_cmd('prev'), h, _toItem);
    await runJamCommand(
      _cmd('seek', <String, dynamic>{'position_ms': 1500}),
      h,
      _toItem,
    );
    verifyInOrder(<void Function()>[
      () => h.play(),
      () => h.pause(),
      () => h.skipToNext(),
      () => h.skipToPrevious(),
      () => h.seek(const Duration(milliseconds: 1500)),
    ]);
  });

  test('play does not wait for playback to end', () async {
    when(() => h.play()).thenAnswer((_) => Completer<void>().future);
    await runJamCommand(_cmd('play'), h, _toItem);
    await runJamCommand(_cmd('next'), h, _toItem);
    verify(() => h.skipToNext()).called(1);
  });

  test('unknown kind and malformed payloads are ignored', () async {
    await runJamCommand(_cmd('rewind'), h, _toItem);
    await runJamCommand(
      _cmd('play_songs', <String, dynamic>{'songs': 'x'}),
      h,
      _toItem,
    );
    await runJamCommand(_cmd('seek'), h, _toItem);
    verifyNever(() => h.playAll(any(), startIndex: any(named: 'startIndex')));
    verifyNever(() => h.seek(any()));
  });

  test('jamHostState publishes current + queue from the current index', () {
    final Map<String, dynamic> s = jamHostState(
      current: _item('b'),
      playback: PlaybackState(
        playing: false,
        queueIndex: 1,
        updatePosition: const Duration(seconds: 3),
      ),
      queue: <MediaItem>[
        _item('a'),
        _item('b'),
        const MediaItem(id: 'preview', title: 'no subsonic id'),
        _item('c'),
      ],
      nowMs: 42,
    );
    expect(s['playing'], false);
    expect(s['position_ms'], 3000);
    expect(s['updated_at_ms'], 42);
    expect((s['current'] as Map<String, dynamic>)['id'], 'b');
    expect((s['queue'] as List<dynamic>).map((dynamic e) => e['id']), <String>[
      'b',
      'c',
    ]);
    expect(s['queue_index'], 1);
  });
}
