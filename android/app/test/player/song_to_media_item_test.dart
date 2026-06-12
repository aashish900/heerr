import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/player/song_to_media_item.dart';

void main() {
  String fixedSalt() => 'abcdef123456';
  const String base = 'http://navi.test:4533';
  const String user = 'phone';
  const String pass = 'sesame';

  group('songToMediaItem', () {
    test('builds a stream URL with auth params on the id field', () {
      const Song s = Song(
        id: 'so-1',
        title: 'Let It Happen',
        artist: 'Tame Impala',
        album: 'Currents',
        duration: 467,
      );

      final MediaItem item = songToMediaItem(
        song: s,
        navidromeBaseUrl: base,
        navidromeUsername: user,
        navidromePassword: pass,
        saltGenerator: fixedSalt,
      );

      // id is the stream URL just_audio will open.
      expect(item.id, startsWith('$base/rest/stream.view?'));
      expect(item.id, contains('id=so-1'));
      expect(item.id, contains('u=phone'));
      expect(item.id, contains('s=abcdef123456'));
      // md5("sesameabcdef123456")
      expect(item.id, contains('t='));
      expect(item.id, contains('v=1.16.1'));
      expect(item.id, contains('c=heerr'));
    });

    test('title / artist / album / duration flow through unchanged', () {
      const Song s = Song(
        id: 'so-1',
        title: 'Let It Happen',
        artist: 'Tame Impala',
        album: 'Currents',
        duration: 467,
      );

      final MediaItem item = songToMediaItem(
        song: s,
        navidromeBaseUrl: base,
        navidromeUsername: user,
        navidromePassword: pass,
        saltGenerator: fixedSalt,
      );

      expect(item.title, 'Let It Happen');
      expect(item.artist, 'Tame Impala');
      expect(item.album, 'Currents');
      expect(item.duration, const Duration(seconds: 467));
    });

    test('artUri is set when coverArt is non-empty', () {
      const Song s = Song(
        id: 'so-1',
        title: 't',
        coverArt: 'al-101',
      );
      final MediaItem item = songToMediaItem(
        song: s,
        navidromeBaseUrl: base,
        navidromeUsername: user,
        navidromePassword: pass,
        saltGenerator: fixedSalt,
      );
      expect(item.artUri, isNotNull);
      expect(item.artUri.toString(), contains('getCoverArt.view'));
      expect(item.artUri.toString(), contains('id=al-101'));
    });

    test('artUri is null when coverArt is missing or empty', () {
      const Song s1 = Song(id: 'so-1', title: 't');
      const Song s2 = Song(id: 'so-2', title: 't', coverArt: '');
      for (final Song s in <Song>[s1, s2]) {
        final MediaItem item = songToMediaItem(
          song: s,
          navidromeBaseUrl: base,
          navidromeUsername: user,
          navidromePassword: pass,
          saltGenerator: fixedSalt,
        );
        expect(item.artUri, isNull);
      }
    });

    test('duration is null when Song.duration is null', () {
      const Song s = Song(id: 'so-1', title: 't');
      final MediaItem item = songToMediaItem(
        song: s,
        navidromeBaseUrl: base,
        navidromeUsername: user,
        navidromePassword: pass,
        saltGenerator: fixedSalt,
      );
      expect(item.duration, isNull);
    });

    test('extras carries the Subsonic song id for callers to map back', () {
      const Song s = Song(id: 'so-42', title: 't');
      final MediaItem item = songToMediaItem(
        song: s,
        navidromeBaseUrl: base,
        navidromeUsername: user,
        navidromePassword: pass,
        saltGenerator: fixedSalt,
      );
      expect(item.extras, isNotNull);
      expect(item.extras!['subsonicId'], 'so-42');
    });

    test('localFilePath produces a file:// MediaItem.id (offline playback)',
        () {
      const Song s = Song(
        id: 'so-1',
        title: 'Let It Happen',
        artist: 'Tame Impala',
        album: 'Currents',
        duration: 467,
      );

      final MediaItem item = songToMediaItem(
        song: s,
        navidromeBaseUrl: base,
        navidromeUsername: user,
        navidromePassword: pass,
        localFilePath: '/data/user/0/heerr/files/offline/x/songs/so-1.mp3',
        saltGenerator: fixedSalt,
      );

      expect(item.id, startsWith('file://'));
      expect(item.id, contains('/songs/so-1.mp3'));
      // No Subsonic auth params should leak into the file:// URI.
      expect(item.id, isNot(contains('stream.view')));
      expect(item.id, isNot(contains('t=')));
    });

    test('localFilePath: extras still carry subsonicId (reverse mapping)', () {
      const Song s = Song(id: 'so-42', title: 't');
      final MediaItem item = songToMediaItem(
        song: s,
        navidromeBaseUrl: base,
        navidromeUsername: user,
        navidromePassword: pass,
        localFilePath: '/tmp/songs/so-42.mp3',
      );
      expect(item.extras, isNotNull);
      expect(item.extras!['subsonicId'], 'so-42');
    });

    test('localFilePath: title/artist/album/duration flow through unchanged',
        () {
      const Song s = Song(
        id: 'so-1',
        title: 'Let It Happen',
        artist: 'Tame Impala',
        album: 'Currents',
        duration: 467,
      );
      final MediaItem item = songToMediaItem(
        song: s,
        navidromeBaseUrl: base,
        navidromeUsername: user,
        navidromePassword: pass,
        localFilePath: '/tmp/songs/so-1.mp3',
      );
      expect(item.title, 'Let It Happen');
      expect(item.artist, 'Tame Impala');
      expect(item.album, 'Currents');
      expect(item.duration, const Duration(seconds: 467));
    });

    test('empty localFilePath falls back to the stream URL', () {
      const Song s = Song(id: 'so-1', title: 't');
      final MediaItem item = songToMediaItem(
        song: s,
        navidromeBaseUrl: base,
        navidromeUsername: user,
        navidromePassword: pass,
        localFilePath: '',
        saltGenerator: fixedSalt,
      );
      expect(item.id, startsWith('$base/rest/stream.view?'));
    });
  });
}
