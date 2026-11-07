import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/mix.dart';

void main() {
  test('MixVibe parses {id, title}', () {
    expect(
      MixVibe.fromJson(<String, dynamic>{'id': 'chill', 'title': 'Chill Mix'}),
      const MixVibe(id: 'chill', title: 'Chill Mix'),
    );
  });

  test('MixResponse parses the backend payload, results as RecommendedTracks',
      () {
    final MixResponse mix = MixResponse.fromJson(<String, dynamic>{
      'id': 'party',
      'title': 'Party Mix',
      'personalized': false,
      'results': <Map<String, dynamic>>[
        <String, dynamic>{
          'title': 'Shararat',
          'artist': 'Madhubanti Bagchi',
          'source_url': 'https://music.youtube.com/watch?v=YyepU5ztLf4',
          'score': 1.59,
          'cover_url': 'https://img.youtube.com/vi/YyepU5ztLf4/mqdefault.jpg',
        },
      ],
    });
    expect((mix.id, mix.title, mix.personalized), ('party', 'Party Mix', false));
    expect(mix.results.single.title, 'Shararat');
    expect(mix.results.single.sourceUrl,
        'https://music.youtube.com/watch?v=YyepU5ztLf4');
    expect(mix.results.single.coverUrl,
        'https://img.youtube.com/vi/YyepU5ztLf4/mqdefault.jpg');
    expect(mix.results.single.inLibrary, isFalse);
  });
}
