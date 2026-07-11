import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/album.dart';
import 'package:heerr/providers/library/most_played_artists.dart';

void main() {
  group('mostPlayedArtistsFrom (X5)', () {
    test('dedupes by artistId keeping the first (most played) album', () {
      const List<Album> frequent = <Album>[
        Album(id: 'al-1', name: 'Starboy', artist: 'The Weeknd', artistId: 'ar-w', coverArt: 'c1'),
        Album(id: 'al-2', name: 'After Hours', artist: 'The Weeknd', artistId: 'ar-w', coverArt: 'c2'),
        Album(id: 'al-3', name: 'Currents', artist: 'Tame Impala', artistId: 'ar-t', coverArt: 'c3'),
      ];
      final List<MostPlayedArtist> out = mostPlayedArtistsFrom(frequent);
      expect(out, hasLength(2));
      expect(out.first.artistId, 'ar-w');
      expect(out.first.topAlbumId, 'al-1'); // first wins
      expect(out.first.coverArt, 'c1');
      expect(out.last.name, 'Tame Impala');
    });

    test('skips albums without artistId or artist name', () {
      const List<Album> frequent = <Album>[
        Album(id: 'al-1', name: 'Compilation'),
        Album(id: 'al-2', name: 'Named', artist: 'X', artistId: 'ar-x'),
      ];
      expect(mostPlayedArtistsFrom(frequent), hasLength(1));
    });

    test('caps at $kMostPlayedArtistsCap entries', () {
      final List<Album> frequent = List<Album>.generate(
        20,
        (int i) => Album(
            id: 'al-$i', name: 'A$i', artist: 'Artist $i', artistId: 'ar-$i'),
      );
      expect(mostPlayedArtistsFrom(frequent), hasLength(kMostPlayedArtistsCap));
    });
  });
}
