import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heerr/player/episode_progress_controller.dart';

class _Report {
  _Report(this.episodeId, this.positionS, this.played);
  final String episodeId;
  final int positionS;
  final bool played;
}

class _Recorder {
  final List<_Report> calls = <_Report>[];

  Future<void> call(String episodeId, int positionS, {required bool played}) async {
    calls.add(_Report(episodeId, positionS, played));
  }
}

MediaItem _episodeItem(String id) => MediaItem(
      id: 'https://ex.com/$id.mp3',
      title: id,
      extras: <String, dynamic>{'episodeId': id},
    );

MediaItem _nonEpisodeItem() => const MediaItem(id: 'file:///song.mp3', title: 'song');

PlaybackState _state({required bool playing}) => PlaybackState(playing: playing);

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late StreamController<MediaItem?> items;
  late StreamController<Duration> positions;
  late StreamController<PlaybackState> states;
  late _Recorder rec;
  late DateTime clockNow;
  late EpisodeProgressController controller;

  setUp(() {
    items = StreamController<MediaItem?>.broadcast();
    positions = StreamController<Duration>.broadcast();
    states = StreamController<PlaybackState>.broadcast();
    rec = _Recorder();
    clockNow = DateTime(2026, 1, 1);
    controller = EpisodeProgressController(
      mediaItemStream: items.stream,
      positionStream: positions.stream,
      playbackStateStream: states.stream,
      report: rec.call,
      minInterval: const Duration(seconds: 15),
      now: () => clockNow,
    );
    controller.start();
  });

  tearDown(() async {
    await controller.dispose();
    await items.close();
    await positions.close();
    await states.close();
  });

  test('non-episode media items never trigger a report', () async {
    items.add(_nonEpisodeItem());
    await _flush();
    positions.add(const Duration(seconds: 5));
    await _flush();

    expect(rec.calls, isEmpty);
  });

  test('an episode position tick fires the first report immediately',
      () async {
    items.add(_episodeItem('e1'));
    await _flush();
    positions.add(const Duration(seconds: 3));
    await _flush();

    expect(rec.calls, hasLength(1));
    expect(rec.calls.single.episodeId, 'e1');
    expect(rec.calls.single.positionS, 3);
  });

  test('subsequent ticks within minInterval are throttled', () async {
    items.add(_episodeItem('e1'));
    await _flush();
    positions.add(const Duration(seconds: 1));
    await _flush();
    rec.calls.clear();

    clockNow = clockNow.add(const Duration(seconds: 5));
    positions.add(const Duration(seconds: 6));
    await _flush();

    expect(rec.calls, isEmpty);
  });

  test('a tick past minInterval fires again', () async {
    items.add(_episodeItem('e1'));
    await _flush();
    positions.add(const Duration(seconds: 1));
    await _flush();
    rec.calls.clear();

    clockNow = clockNow.add(const Duration(seconds: 16));
    positions.add(const Duration(seconds: 20));
    await _flush();

    expect(rec.calls, hasLength(1));
    expect(rec.calls.single.positionS, 20);
  });

  test('pausing forces an immediate report even inside the throttle window',
      () async {
    items.add(_episodeItem('e1'));
    await _flush();
    states.add(_state(playing: true));
    positions.add(const Duration(seconds: 2));
    await _flush();
    rec.calls.clear();

    states.add(_state(playing: false));
    await _flush();

    expect(rec.calls, hasLength(1));
    expect(rec.calls.single.positionS, 2);
  });

  test('switching away from an episode force-reports its last position',
      () async {
    items.add(_episodeItem('e1'));
    await _flush();
    positions.add(const Duration(seconds: 7));
    await _flush();
    rec.calls.clear();

    items.add(_nonEpisodeItem());
    await _flush();

    expect(rec.calls, hasLength(1));
    expect(rec.calls.single.episodeId, 'e1');
    expect(rec.calls.single.positionS, 7);
  });

  test('switching between two different episodes reports the first one',
      () async {
    items.add(_episodeItem('e1'));
    await _flush();
    positions.add(const Duration(seconds: 9));
    await _flush();
    rec.calls.clear();

    items.add(_episodeItem('e2'));
    await _flush();

    expect(rec.calls, hasLength(1));
    expect(rec.calls.single.episodeId, 'e1');
    expect(rec.calls.single.positionS, 9);
  });
}
