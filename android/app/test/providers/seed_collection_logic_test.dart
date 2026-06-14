import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/album.dart';
import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/providers/recommendations.dart';

Song _song({
  required String id,
  required String title,
  String? artist,
}) {
  return Song(id: id, title: title, artist: artist);
}

Album _album({
  required String id,
  required String name,
  String? artist,
}) {
  return Album(id: id, name: name, artist: artist);
}

void main() {
  group('buildSeedCollection', () {
    test('returns empty when every source is empty', () {
      final result = buildSeedCollection(
        starred: const <Song>[],
        frequent: const <Album>[],
        favourites: const <Song>[],
      );
      expect(result, isEmpty);
    });

    test('starred-only source produces seeds in source order', () {
      final result = buildSeedCollection(
        starred: <Song>[
          _song(id: 's1', title: 'A', artist: 'X'),
          _song(id: 's2', title: 'B', artist: 'Y'),
        ],
        frequent: const <Album>[],
        favourites: const <Song>[],
      );
      expect(result.map((s) => '${s.title}/${s.artist}').toList(),
          <String>['A/X', 'B/Y']);
    });

    test('starred ranks before frequent in the merged list', () {
      final result = buildSeedCollection(
        starred: <Song>[
          _song(id: 's1', title: 'Star1', artist: 'SA'),
        ],
        frequent: <Album>[
          _album(id: 'a1', name: 'AlbumName', artist: 'AA'),
        ],
        favourites: const <Song>[],
      );
      expect(result.map((s) => s.title).toList(),
          <String>['Star1', 'AlbumName']);
    });

    test('dedup by title+artist is case-insensitive', () {
      final result = buildSeedCollection(
        starred: <Song>[
          _song(id: 's1', title: 'Hello', artist: 'Adele'),
        ],
        frequent: <Album>[
          _album(id: 'a1', name: 'HELLO', artist: 'adele'),
        ],
        favourites: const <Song>[],
      );
      expect(result, hasLength(1));
      expect(result.first.title, 'Hello');
      expect(result.first.artist, 'Adele');
    });

    test('dedup trims whitespace before comparing', () {
      final result = buildSeedCollection(
        starred: <Song>[
          _song(id: 's1', title: '  Hello  ', artist: 'Adele'),
        ],
        frequent: <Album>[
          _album(id: 'a1', name: 'Hello', artist: '  Adele  '),
        ],
        favourites: const <Song>[],
      );
      expect(result, hasLength(1));
    });

    test('skips entries with missing or whitespace-only artist', () {
      final result = buildSeedCollection(
        starred: <Song>[
          _song(id: 's1', title: 'NoArtist', artist: null),
          _song(id: 's2', title: 'Blank', artist: '   '),
          _song(id: 's3', title: 'OK', artist: 'X'),
        ],
        frequent: const <Album>[],
        favourites: const <Song>[],
      );
      expect(result.map((s) => s.title).toList(), <String>['OK']);
    });

    test('skips entries with missing or whitespace-only title', () {
      final result = buildSeedCollection(
        starred: <Song>[
          _song(id: 's1', title: '', artist: 'X'),
          _song(id: 's2', title: '   ', artist: 'Y'),
          _song(id: 's3', title: 'OK', artist: 'Z'),
        ],
        frequent: const <Album>[],
        favourites: const <Song>[],
      );
      expect(result.map((s) => s.title).toList(), <String>['OK']);
    });

    test('respects the maxSeeds cap (default 20)', () {
      final starred = List<Song>.generate(
        25,
        (i) => _song(id: 's$i', title: 'T$i', artist: 'A$i'),
      );
      final result = buildSeedCollection(
        starred: starred,
        frequent: const <Album>[],
        favourites: const <Song>[],
      );
      expect(result, hasLength(20));
      expect(result.first.title, 'T0');
      expect(result.last.title, 'T19');
    });

    test('respects an explicit maxSeeds value', () {
      final result = buildSeedCollection(
        starred: <Song>[
          _song(id: 's1', title: 'A', artist: 'X'),
          _song(id: 's2', title: 'B', artist: 'Y'),
          _song(id: 's3', title: 'C', artist: 'Z'),
        ],
        frequent: const <Album>[],
        favourites: const <Song>[],
        maxSeeds: 2,
      );
      expect(result, hasLength(2));
      expect(result.map((s) => s.title).toList(), <String>['A', 'B']);
    });

    test('Favourites fallback fires when both primary sources are empty', () {
      final result = buildSeedCollection(
        starred: const <Song>[],
        frequent: const <Album>[],
        favourites: <Song>[
          _song(id: 'f1', title: 'FavT', artist: 'FavA'),
        ],
      );
      expect(result, hasLength(1));
      expect(result.first.title, 'FavT');
    });

    test('Favourites fallback is skipped when starred has at least one seed',
        () {
      final result = buildSeedCollection(
        starred: <Song>[
          _song(id: 's1', title: 'Star', artist: 'SA'),
        ],
        frequent: const <Album>[],
        favourites: <Song>[
          _song(id: 'f1', title: 'FavT', artist: 'FavA'),
        ],
      );
      expect(result.map((s) => s.title).toList(), <String>['Star']);
    });

    test('Favourites fallback is skipped when frequent has at least one seed',
        () {
      final result = buildSeedCollection(
        starred: const <Song>[],
        frequent: <Album>[
          _album(id: 'a1', name: 'Album', artist: 'AA'),
        ],
        favourites: <Song>[
          _song(id: 'f1', title: 'FavT', artist: 'FavA'),
        ],
      );
      expect(result.map((s) => s.title).toList(), <String>['Album']);
    });

    test('Favourites fallback also dedupes and respects the cap', () {
      final favourites = List<Song>.generate(
        25,
        (i) => _song(id: 'f$i', title: 'F$i', artist: 'A$i'),
      );
      // include one whitespace-noisy duplicate.
      favourites.add(_song(id: 'fdup', title: '  F0  ', artist: 'a0'));
      final result = buildSeedCollection(
        starred: const <Song>[],
        frequent: const <Album>[],
        favourites: favourites,
        maxSeeds: 5,
      );
      expect(result, hasLength(5));
      expect(result.first.title, 'F0');
    });
  });
}
