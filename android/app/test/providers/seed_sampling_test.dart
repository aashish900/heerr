import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:heerr/models/seed_track.dart';
import 'package:heerr/providers/recommendations.dart';

List<SeedTrack> _seeds(int n) => List<SeedTrack>.generate(
      n,
      (int i) => SeedTrack(title: 'Track $i', artist: 'Artist $i'),
    );

void main() {
  group('sampleSeeds', () {
    test('returns sampleSize seeds when input exceeds sampleSize', () {
      final List<SeedTrack> input = _seeds(20);
      final List<SeedTrack> out = sampleSeeds(input, rng: Random(42));
      expect(out.length, kSeedSampleSize);
      expect(out.toSet().length, kSeedSampleSize, reason: 'no duplicates');
      for (final SeedTrack s in out) {
        expect(input, contains(s));
      }
    });

    test('returns all seeds when input is at or below sampleSize', () {
      final List<SeedTrack> input = _seeds(5);
      final List<SeedTrack> out = sampleSeeds(input, rng: Random(42));
      expect(out.length, 5);
      expect(out.toSet(), input.toSet());
    });

    test('is deterministic for a seeded Random', () {
      final List<SeedTrack> input = _seeds(20);
      final List<SeedTrack> a = sampleSeeds(input, rng: Random(42));
      final List<SeedTrack> b = sampleSeeds(input, rng: Random(42));
      expect(a, b);
    });

    test('successive calls on one Random instance produce different samples',
        () {
      final Random rng = Random(42);
      final List<SeedTrack> input = _seeds(20);
      final List<SeedTrack> a = sampleSeeds(input, rng: rng);
      final List<SeedTrack> b = sampleSeeds(input, rng: rng);
      expect(a, isNot(equals(b)));
    });

    test('does not mutate the input list', () {
      final List<SeedTrack> input = _seeds(20);
      final List<SeedTrack> before = List<SeedTrack>.of(input);
      sampleSeeds(input, rng: Random(42));
      expect(input, before);
    });
  });
}
