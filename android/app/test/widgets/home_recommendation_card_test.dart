import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/download_response.dart';
import 'package:heerr/models/enums.dart';
import 'package:heerr/models/recommended_track.dart';
import 'package:heerr/providers/download.dart';
import 'package:heerr/widgets/home_recommendation_card.dart';

class _RecordingDispatcher extends DownloadDispatcher {
  final List<String> calls = <String>[];

  @override
  Set<String> build() => const <String>{};

  @override
  Future<DownloadResponse> dispatch(
    String sourceUrl, {
    required String sourceType,
    String? displayName,
  }) async {
    calls.add(sourceUrl);
    state = <String>{...state, sourceUrl};
    return const DownloadResponse(
      jobId: 'job-1',
      state: JobState.queued,
      deduped: false,
    );
  }
}

Widget _wrap({required Widget child, List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1DB954),
          brightness: Brightness.dark,
        ),
      ),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  testWidgets(
    'inLibrary=true + subsonicSongId set → renders Play button',
    (WidgetTester tester) async {
      const RecommendedTrack t = RecommendedTrack(
        title: 'Song A',
        artist: 'Artist A',
        sourceUrl: '',
        inLibrary: true,
        subsonicSongId: 'sg-1',
      );
      await tester.pumpWidget(_wrap(child: const HomeRecommendationCard(track: t)));

      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Download'), findsNothing);
      expect(find.text('Song A'), findsOneWidget);
      expect(find.text('Artist A'), findsOneWidget);
    },
  );

  group('extractYoutubeVideoId', () {
    test('music.youtube.com watch?v=...', () {
      expect(
        extractYoutubeVideoId('https://music.youtube.com/watch?v=abc123'),
        'abc123',
      );
    });
    test('youtube.com watch?v=...', () {
      expect(
        extractYoutubeVideoId('https://www.youtube.com/watch?v=def456'),
        'def456',
      );
    });
    test('youtu.be short form', () {
      expect(
        extractYoutubeVideoId('https://youtu.be/xyz789'),
        'xyz789',
      );
    });
    test('empty string → null', () {
      expect(extractYoutubeVideoId(''), isNull);
    });
    test('non-youtube URL → null', () {
      expect(
        extractYoutubeVideoId('https://spotify.com/track/123'),
        isNull,
      );
    });
    test('watch URL missing v param → null', () {
      expect(
        extractYoutubeVideoId('https://music.youtube.com/watch?foo=bar'),
        isNull,
      );
    });
  });

  test('youtubeThumbnailUrl builds an img.youtube.com URL', () {
    expect(
      youtubeThumbnailUrl('abc123'),
      'https://img.youtube.com/vi/abc123/mqdefault.jpg',
    );
  });

  testWidgets(
    'inLibrary=false → renders Download button and fires the dispatcher',
    (WidgetTester tester) async {
      final _RecordingDispatcher dispatcher = _RecordingDispatcher();
      const RecommendedTrack t = RecommendedTrack(
        title: 'Remote',
        artist: 'X',
        sourceUrl: 'https://music.youtube.com/watch?v=abc',
      );
      await tester.pumpWidget(_wrap(
        child: const HomeRecommendationCard(track: t),
        overrides: <Override>[
          downloadDispatcherProvider.overrideWith(() => dispatcher),
        ],
      ));

      expect(find.text('Download'), findsOneWidget);
      expect(find.text('Play'), findsNothing);

      await tester.tap(find.text('Download'));
      await tester.pump();

      expect(dispatcher.calls, <String>[
        'https://music.youtube.com/watch?v=abc',
      ]);
    },
  );
}
