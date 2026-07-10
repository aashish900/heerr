import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/download_response.dart';
import 'package:heerr/models/enums.dart';
import 'package:heerr/models/recommended_track.dart';
import 'package:heerr/providers/download.dart';
import 'package:heerr/theme.dart';
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
      theme: heerrDarkTheme(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  testWidgets(
    'inLibrary=true + subsonicSongId set → renders play overlay, no download',
    (WidgetTester tester) async {
      const RecommendedTrack t = RecommendedTrack(
        title: 'Song A',
        artist: 'Artist A',
        sourceUrl: '',
        inLibrary: true,
        subsonicSongId: 'sg-1',
      );
      await tester.pumpWidget(_wrap(child: const HomeRecommendationCard(track: t)));

      expect(find.byKey(const Key('rec-play')), findsOneWidget);
      expect(find.byKey(const Key('rec-download')), findsNothing);
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
    'inLibrary=false → renders download overlay and fires the dispatcher',
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

      expect(find.byKey(const Key('rec-download')), findsOneWidget);
      expect(find.byKey(const Key('rec-play')), findsNothing);

      await tester.tap(find.byKey(const Key('rec-download')));
      await tester.pump();

      expect(dispatcher.calls, <String>[
        'https://music.youtube.com/watch?v=abc',
      ]);
    },
  );

  testWidgets(
    'download in-flight → spinner shown, dispatcher not re-fired on tap',
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

      // First tap dispatches and flips to in-flight (sourceUrl now in state).
      await tester.tap(find.byKey(const Key('rec-download')));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Tapping again while in-flight must not re-dispatch.
      await tester.tap(find.byKey(const Key('rec-download')));
      await tester.pump();
      expect(dispatcher.calls, <String>[
        'https://music.youtube.com/watch?v=abc',
      ]);
    },
  );
}
