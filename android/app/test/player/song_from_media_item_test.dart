import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/player/song_to_media_item.dart';

void main() {
  group('songFromMediaItem', () {
    test('extracts subsonicId + coverArt + title/artist/album/duration',
        () {
      final MediaItem item = const MediaItem(
        id: 'http://navi/rest/stream.view?id=so-1&...',
        title: 'Let It Happen',
        artist: 'Tame Impala',
        album: 'Currents',
        duration: Duration(seconds: 467),
        extras: <String, dynamic>{
          'subsonicId': 'so-1',
          'coverArt': 'al-99',
        },
      );

      final Song? back = songFromMediaItem(item);
      expect(back, isNotNull);
      expect(back!.id, 'so-1');
      expect(back.title, 'Let It Happen');
      expect(back.artist, 'Tame Impala');
      expect(back.album, 'Currents');
      expect(back.duration, 467);
      expect(back.coverArt, 'al-99');
    });

    test('returns null when subsonicId is missing', () {
      final MediaItem item = const MediaItem(
        id: 'file:///some/local/file.m4a',
        title: 'no-extras',
      );
      expect(songFromMediaItem(item), isNull);
    });

    test('returns null when subsonicId is empty', () {
      final MediaItem item = const MediaItem(
        id: 'x',
        title: 'empty-id',
        extras: <String, dynamic>{'subsonicId': ''},
      );
      expect(songFromMediaItem(item), isNull);
    });

    test('coverArt is null when extras do not carry one', () {
      final MediaItem item = const MediaItem(
        id: 'x',
        title: 'plain',
        extras: <String, dynamic>{'subsonicId': 'so-9'},
      );
      final Song? back = songFromMediaItem(item);
      expect(back, isNotNull);
      expect(back!.coverArt, isNull);
    });

    test('round-trip via songToMediaItem preserves the fields we care about',
        () {
      const Song original = Song(
        id: 'so-7',
        title: 'Hex',
        artist: 'Modeselektor',
        album: 'Happy Birthday!',
        duration: 312,
        coverArt: 'al-7',
      );
      final MediaItem item = songToMediaItem(
        song: original,
        navidromeBaseUrl: 'http://navi.test:4533',
        navidromeUsername: 'phone',
        navidromePassword: 'sesame',
      );
      final Song? back = songFromMediaItem(item);
      expect(back, isNotNull);
      expect(back!.id, original.id);
      expect(back.title, original.title);
      expect(back.artist, original.artist);
      expect(back.album, original.album);
      expect(back.duration, original.duration);
      expect(back.coverArt, original.coverArt);
    });
  });
}
