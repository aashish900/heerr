import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/seed_track.dart';

void main() {
  test('song seed serialises title, artist and weight', () {
    expect(
      const SeedTrack(title: 'Co2', artist: 'Prateek Kuhad').toJson(),
      <String, dynamic>{'title': 'Co2', 'artist': 'Prateek Kuhad', 'weight': 1.0},
    );
  });

  test('artist seed omits title (backend reads absence as an artist seed)', () {
    expect(
      const SeedTrack(artist: 'The Local Train', weight: 0.7).toJson(),
      <String, dynamic>{'artist': 'The Local Train', 'weight': 0.7},
    );
  });
}
