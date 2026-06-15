import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/lyrics.dart';

void main() {
  group('Lyrics', () {
    test('round-trips full envelope', () {
      const Lyrics l = Lyrics(
        artist: 'Tame Impala',
        title: 'Let It Happen',
        value: "It's always the same…",
      );
      final Lyrics back = Lyrics.fromJson(l.toJson());
      expect(back, l);
    });

    test('handles missing fields', () {
      final Lyrics back =
          Lyrics.fromJson(<String, dynamic>{'value': 'just lyrics'});
      expect(back.artist, isNull);
      expect(back.title, isNull);
      expect(back.value, 'just lyrics');
    });

    test('handles empty envelope', () {
      final Lyrics back = Lyrics.fromJson(const <String, dynamic>{});
      expect(back.artist, isNull);
      expect(back.title, isNull);
      expect(back.value, isNull);
    });
  });
}
