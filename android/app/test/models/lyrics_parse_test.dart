import 'package:flutter_test/flutter_test.dart';
import 'package:heerr/models/subsonic/lyrics.dart';

void main() {
  group('parseLrc (#26)', () {
    test('parses basic [mm:ss.xx] lines in order', () {
      final List<LyricsLine> lines = parseLrc(
        '[00:12.50] First line\n[01:02.00] Second line',
      );
      expect(lines, const <LyricsLine>[
        LyricsLine(start: 12500, value: 'First line'),
        LyricsLine(start: 62000, value: 'Second line'),
      ]);
    });

    test('normalises 1/2/3-digit fractions to milliseconds', () {
      final List<LyricsLine> lines = parseLrc(
        '[00:01.5] a\n[00:02.50] b\n[00:03.500] c\n[00:04] d',
      );
      expect(
        lines.map((LyricsLine l) => l.start),
        <int>[1500, 2500, 3500, 4000],
      );
    });

    test('repeats text for multi-timestamp lines and sorts by start', () {
      final List<LyricsLine> lines =
          parseLrc('[00:30.00][00:10.00] Chorus\n[00:20.00] Verse');
      expect(lines, const <LyricsLine>[
        LyricsLine(start: 10000, value: 'Chorus'),
        LyricsLine(start: 20000, value: 'Verse'),
        LyricsLine(start: 30000, value: 'Chorus'),
      ]);
    });

    test('skips metadata tags, untimed lines, and empty texts', () {
      final List<LyricsLine> lines = parseLrc(
        '[ar:Artist]\n[ti:Title]\nno timestamp here\n[00:05.00]\n[00:06.00] real',
      );
      expect(lines, const <LyricsLine>[
        LyricsLine(start: 6000, value: 'real'),
      ]);
    });

    test('empty / garbage input yields empty list', () {
      expect(parseLrc(''), isEmpty);
      expect(parseLrc('complete garbage'), isEmpty);
    });
  });
}
