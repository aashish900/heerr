import 'package:flutter_test/flutter_test.dart';
import 'package:heerr/player/browse_ids.dart';

void main() {
  group('BrowseId', () {
    test('root and tab ids are bare words; root matches audio_service', () {
      expect(BrowseId.root.encoded, 'root');
      expect(const BrowseId(BrowseKind.recents).encoded, 'recents');
      expect(const BrowseId(BrowseKind.downloaded).encoded, 'downloaded');
    });

    test('entity ids encode as kind:id', () {
      expect(const BrowseId(BrowseKind.album, 'al-1').encoded, 'album:al-1');
      expect(const BrowseId(BrowseKind.artist, 'ar-9').encoded, 'artist:ar-9');
      expect(const BrowseId(BrowseKind.playlist, 'p1').encoded, 'playlist:p1');
    });

    test('song carries its parent so the whole container can be queued', () {
      const parent = BrowseId(BrowseKind.album, 'al-1');
      const song = BrowseId(BrowseKind.song, 's7', parent);
      expect(song.encoded, 'album:al-1/song:s7');
      expect(BrowseId.tryParse('album:al-1/song:s7'), song);
      expect(
        BrowseId.tryParse('song:s7'),
        const BrowseId(BrowseKind.song, 's7'),
      );
    });

    test('round-trips every kind', () {
      final ids = [
        BrowseId.root,
        for (final k in [
          BrowseKind.recents,
          BrowseKind.favourites,
          BrowseKind.playlists,
          BrowseKind.albums,
          BrowseKind.artists,
          BrowseKind.downloaded,
        ])
          BrowseId(k),
        const BrowseId(BrowseKind.album, 'a'),
        const BrowseId(BrowseKind.artist, 'b'),
        const BrowseId(BrowseKind.playlist, 'c'),
        const BrowseId(BrowseKind.song, 'd'),
        const BrowseId(
          BrowseKind.song,
          'd',
          BrowseId(BrowseKind.playlist, 'c'),
        ),
        const BrowseId(BrowseKind.song, 'd', BrowseId(BrowseKind.favourites)),
      ];
      for (final id in ids) {
        expect(BrowseId.tryParse(id.encoded), id, reason: id.encoded);
      }
    });

    test('ids containing delimiters survive the round trip', () {
      const id = BrowseId(
        BrowseKind.song,
        'a:b/c d%',
        BrowseId(BrowseKind.album, 'x/y:z'),
      );
      expect(BrowseId.tryParse(id.encoded), id);
    });

    test('malformed input parses to null', () {
      for (final s in [
        '',
        'bogus',
        'album', // entity kind without id
        'album:', // empty id
        'recents:5', // tab kind with id
        'song:s/album:a', // song as parent
        'album:a/album:b', // non-song child
        'album:a/song:s/song:t', // too deep
        'root/song:s',
      ]) {
        expect(BrowseId.tryParse(s), isNull, reason: s);
      }
    });
  });
}
