import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/player/now_playing_snapshot.dart';

void main() {
  group('NowPlayingSnapshot', () {
    test('round-trips through JSON', () {
      const NowPlayingSnapshot s = NowPlayingSnapshot(
        songs: <Song>[
          Song(id: 'so-1', title: 'Track One', artist: 'A', duration: 240),
          Song(id: 'so-2', title: 'Track Two', artist: 'B', coverArt: 'al-7'),
        ],
        currentIndex: 1,
        positionMs: 42_000,
        updatedAt: 1_700_000_000_000,
      );

      final Map<String, dynamic> json = s.toJson();
      final NowPlayingSnapshot back = NowPlayingSnapshot.fromJson(json);

      expect(back, s);
      expect(back.songs[0].title, 'Track One');
      expect(back.songs[1].coverArt, 'al-7');
    });

    test('empty defaults round-trip', () {
      const NowPlayingSnapshot s = NowPlayingSnapshot();
      final NowPlayingSnapshot back = NowPlayingSnapshot.fromJson(s.toJson());
      expect(back.songs, isEmpty);
      expect(back.currentIndex, 0);
      expect(back.positionMs, 0);
      expect(back.updatedAt, 0);
    });
  });
}
