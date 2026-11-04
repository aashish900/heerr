import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/player/playback_actions.dart';

// Orchestration seam of the Home "Shuffle all" button: pure list logic, no
// Riverpod / handler. First chunk starts playback, the rest is appended.

List<Song> _songs(int n) =>
    List<Song>.generate(n, (int i) => Song(id: 's$i', title: 'T$i'));

void main() {
  test('shuffles everything once, plays first chunk, appends the rest in order',
      () async {
    final List<List<String>> played = <List<String>>[];
    final List<List<String>> appended = <List<String>>[];

    final int n = await playShuffledInChunks(
      _songs(1016),
      play: (List<Song> s) async => played.add(s.map((e) => e.id).toList()),
      append: (List<Song> s) async => appended.add(s.map((e) => e.id).toList()),
      rng: Random(1),
    );

    expect(n, 1016);
    expect(played.single.length, shuffleFirstChunk);
    expect(appended.every((c) => c.length <= shuffleAppendChunk), isTrue);
    final List<String> all = <String>[...played.single, ...appended.expand((c) => c)];
    expect(all.length, 1016);
    expect(all.toSet().length, 1016); // no dupes, nothing lost
    expect(all, isNot(_songs(1016).map((s) => s.id).toList())); // actually shuffled
  });

  test('stops appending once shouldContinue turns false', () async {
    int appendCalls = 0;
    await playShuffledInChunks(
      _songs(1000),
      play: (_) async {},
      append: (_) async => appendCalls++,
      shouldContinue: () => appendCalls < 2,
    );
    expect(appendCalls, 2);
  });

  _offline();

  test('small list: play only, no append; empty list: nothing', () async {
    int appends = 0;
    expect(
      await playShuffledInChunks(_songs(3),
          play: (_) async {}, append: (_) async => appends++),
      3,
    );
    expect(appends, 0);
    bool played = false;
    expect(
      await playShuffledInChunks(<Song>[],
          play: (_) async => played = true, append: (_) async {}),
      0,
    );
    expect(played, isFalse);
  });
}

void _offline() {
  test('online failure falls back to downloaded songs', () async {
    final List<Song> got = await songsForShuffleAll(
      online: () async => throw Exception('no route'),
      downloaded: () async => _songs(4),
    );
    expect(got.length, 4);
  });

  test('online success never touches downloads', () async {
    final List<Song> got = await songsForShuffleAll(
      online: () async => _songs(7),
      downloaded: () async => throw StateError('should not be called'),
    );
    expect(got.length, 7);
  });

  test('online failure + nothing downloaded rethrows the online error', () async {
    expect(
      songsForShuffleAll(
        online: () async => throw Exception('no route'),
        downloaded: () async => <Song>[],
      ),
      throwsA(predicate((e) => e.toString().contains('no route'))),
    );
  });
}
