import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heerr/player/scrobble_controller.dart';

class _ScrobbleCall {
  _ScrobbleCall(this.id, this.submission);
  final String id;
  final bool submission;

  @override
  String toString() => '$id/$submission';
}

class _Recorder {
  final List<_ScrobbleCall> calls = <_ScrobbleCall>[];

  Future<void> call(String id, {required bool submission}) async {
    calls.add(_ScrobbleCall(id, submission));
  }
}

MediaItem _item({
  required String trackId,
  Duration? duration,
  String? subsonicId,
}) {
  return MediaItem(
    id: 'file:///$trackId',
    title: trackId,
    duration: duration,
    extras: subsonicId == null
        ? null
        : <String, dynamic>{'subsonicId': subsonicId},
  );
}

Future<void> _flush() async {
  // Two microtask yields cover (a) the stream listener delivering and
  // (b) the async ScrobbleCall await inside `_onMediaItem` / `_onPosition`.
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late StreamController<MediaItem?> items;
  late StreamController<Duration> positions;
  late _Recorder rec;
  late ScrobbleController controller;

  setUp(() {
    items = StreamController<MediaItem?>.broadcast();
    positions = StreamController<Duration>.broadcast();
    rec = _Recorder();
    controller = ScrobbleController(
      mediaItemStream: items.stream,
      positionStream: positions.stream,
      scrobble: rec.call,
    );
    controller.start();
  });

  tearDown(() async {
    await controller.dispose();
    await items.close();
    await positions.close();
  });

  test('track start fires submission=false with the subsonic id', () async {
    items.add(_item(
      trackId: 'a',
      duration: const Duration(seconds: 100),
      subsonicId: 'sid-1',
    ));
    await _flush();

    expect(rec.calls, hasLength(1));
    expect(rec.calls.first.id, 'sid-1');
    expect(rec.calls.first.submission, false);
  });

  test('position at ≥ 50% fires submission=true exactly once', () async {
    items.add(_item(
      trackId: 'a',
      duration: const Duration(seconds: 100),
      subsonicId: 'sid-1',
    ));
    await _flush();
    rec.calls.clear();

    positions.add(const Duration(seconds: 49));
    await _flush();
    expect(rec.calls, isEmpty, reason: '49 % must not fire submission');

    positions.add(const Duration(seconds: 50));
    await _flush();
    expect(rec.calls, hasLength(1));
    expect(rec.calls.first.id, 'sid-1');
    expect(rec.calls.first.submission, true);

    // Further position ticks (including seeks back-and-forth) must not
    // re-fire — once per play.
    positions.add(const Duration(seconds: 75));
    positions.add(const Duration(seconds: 30));
    positions.add(const Duration(seconds: 99));
    await _flush();
    expect(rec.calls, hasLength(1));
  });

  test('track change resets the submission guard for the new track', () async {
    items.add(_item(
      trackId: 'a',
      duration: const Duration(seconds: 100),
      subsonicId: 'sid-1',
    ));
    await _flush();
    positions.add(const Duration(seconds: 50));
    await _flush();
    expect(
      rec.calls.map((_ScrobbleCall c) => c.toString()).toList(),
      <String>['sid-1/false', 'sid-1/true'],
    );
    rec.calls.clear();

    items.add(_item(
      trackId: 'b',
      duration: const Duration(seconds: 100),
      subsonicId: 'sid-2',
    ));
    await _flush();
    expect(rec.calls, hasLength(1));
    expect(rec.calls.first.id, 'sid-2');
    expect(rec.calls.first.submission, false);
    rec.calls.clear();

    positions.add(const Duration(seconds: 50));
    await _flush();
    expect(rec.calls, hasLength(1));
    expect(rec.calls.first.id, 'sid-2');
    expect(rec.calls.first.submission, true);
  });

  test('re-emission of the same MediaItem does not re-fire submission=false',
      () async {
    items.add(_item(
      trackId: 'a',
      duration: const Duration(seconds: 100),
      subsonicId: 'sid-1',
    ));
    items.add(_item(
      trackId: 'a',
      duration: const Duration(seconds: 100),
      subsonicId: 'sid-1',
    ));
    await _flush();

    expect(rec.calls, hasLength(1));
  });

  test('null mediaItem clears state — same track refires after a stop',
      () async {
    items.add(_item(
      trackId: 'a',
      duration: const Duration(seconds: 100),
      subsonicId: 'sid-1',
    ));
    await _flush();
    rec.calls.clear();

    items.add(null);
    await _flush();
    expect(rec.calls, isEmpty);

    items.add(_item(
      trackId: 'a',
      duration: const Duration(seconds: 100),
      subsonicId: 'sid-1',
    ));
    await _flush();
    expect(rec.calls, hasLength(1));
    expect(rec.calls.first.submission, false);
  });

  test('mediaItem without subsonicId extra fires no scrobbles', () async {
    items.add(_item(trackId: 'a', duration: const Duration(seconds: 100)));
    await _flush();
    positions.add(const Duration(seconds: 50));
    await _flush();

    expect(rec.calls, isEmpty);
  });

  test('null duration suppresses submission but still fires now-playing',
      () async {
    items.add(_item(trackId: 'a', subsonicId: 'sid-1'));
    await _flush();
    expect(rec.calls, hasLength(1));
    expect(rec.calls.first.submission, false);
    rec.calls.clear();

    positions.add(const Duration(seconds: 50));
    positions.add(const Duration(seconds: 999));
    await _flush();
    expect(rec.calls, isEmpty);
  });

  test('zero duration does not divide by zero or fire submission', () async {
    items.add(_item(
      trackId: 'a',
      duration: Duration.zero,
      subsonicId: 'sid-1',
    ));
    await _flush();
    rec.calls.clear();

    positions.add(const Duration(milliseconds: 1));
    await _flush();
    expect(rec.calls, isEmpty);
  });

  test('exception from scrobble call is swallowed', () async {
    int attempts = 0;
    final ScrobbleController throwing = ScrobbleController(
      mediaItemStream: items.stream,
      positionStream: positions.stream,
      scrobble: (String id, {required bool submission}) async {
        attempts += 1;
        throw Exception('network down');
      },
    );
    throwing.start();

    items.add(_item(
      trackId: 'a',
      duration: const Duration(seconds: 100),
      subsonicId: 'sid-1',
    ));
    await _flush();
    positions.add(const Duration(seconds: 50));
    await _flush();

    expect(attempts, 2,
        reason: 'both now-playing and submission must be attempted');
    await throwing.dispose();
  });

  test('after dispose, further stream events are not processed', () async {
    items.add(_item(
      trackId: 'a',
      duration: const Duration(seconds: 100),
      subsonicId: 'sid-1',
    ));
    await _flush();
    await controller.dispose();
    rec.calls.clear();

    items.add(_item(
      trackId: 'b',
      duration: const Duration(seconds: 100),
      subsonicId: 'sid-2',
    ));
    positions.add(const Duration(seconds: 80));
    await _flush();
    expect(rec.calls, isEmpty);
  });
}
