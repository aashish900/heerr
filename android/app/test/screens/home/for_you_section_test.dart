import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:heerr/models/profile_meta.dart';
import 'package:heerr/models/recommended_track.dart';
import 'package:heerr/player/heerr_audio_handler.dart';
import 'package:heerr/player/player_provider.dart';
import 'package:heerr/providers/profiles/profile_meta.dart';
import 'package:heerr/providers/recommendations.dart';
import 'package:heerr/screens/home/for_you_section.dart';
import 'package:heerr/theme.dart';

import '../../support/cred_test_support.dart';

class _MockHandler extends Mock implements HeerrAudioHandler {}

class _StubRecs extends Recommendations {
  _StubRecs(this._load);
  final Future<List<RecommendedTrack>> Function() _load;
  int refreshCalls = 0;

  @override
  Future<List<RecommendedTrack>> build() => _load();

  @override
  Future<void> refresh() async => refreshCalls++;
}

class _StubMeta extends ProfileMetaNotifier {
  _StubMeta(this._nickname);
  final String? _nickname;

  @override
  Future<ProfileMeta> build() async => ProfileMeta(nickname: _nickname);
}

RecommendedTrack _track(int i) => RecommendedTrack(
  title: 'Song $i',
  artist: 'Artist $i',
  sourceUrl: 'https://music.youtube.com/watch?v=v$i',
);

List<RecommendedTrack> _tracks(int n) =>
    List<RecommendedTrack>.generate(n, _track);

Widget _wrap({
  required Future<List<RecommendedTrack>> Function() recs,
  String? nickname,
  HeerrAudioHandler? handler,
  _StubRecs? stub,
}) {
  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) =>
            const Scaffold(body: SingleChildScrollView(child: ForYouSection())),
      ),
      GoRoute(
        path: '/library/recommendations',
        builder: (_, _) => const Scaffold(body: Text('RECS_SCREEN')),
      ),
    ],
  );
  return ProviderScope(
    overrides: <Override>[
      recommendationsProvider.overrideWith(() => stub ?? _StubRecs(recs)),
      profileMetaNotifierProvider.overrideWith(() => _StubMeta(nickname)),
      activeProfileOverride(),
      if (handler != null) audioHandlerProvider.overrideWithValue(handler),
    ],
    child: MaterialApp.router(theme: heerrDarkTheme(), routerConfig: router),
  );
}

Finder _cards() => find.byKey(const ValueKey<String>('for-you-card'));

void main() {
  setUpAll(() => registerFallbackValue(const MediaItem(id: 'x', title: 'x')));

  testWidgets('hidden when the API returns no recommendations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(recs: () async => <RecommendedTrack>[]));
    await tester.pumpAndSettle();

    expect(find.text('For You'), findsNothing);
    expect(_cards(), findsNothing);
  });

  testWidgets('hidden when the recommendations call fails', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(recs: () async => throw Exception('down')));
    await tester.pumpAndSettle();

    expect(find.text('For You'), findsNothing);
  });

  testWidgets('header: "Made for <nickname>", "For You", See all', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(recs: () async => _tracks(3), nickname: 'Aashish'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Made for Aashish'), findsOneWidget);
    expect(find.text('For You'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
  });

  testWidgets('header falls back to "Made for you" without a nickname', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(recs: () async => _tracks(3)));
    await tester.pumpAndSettle();

    expect(find.text('Made for you'), findsOneWidget);
  });

  testWidgets('See all opens the For You screen', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(recs: () async => _tracks(3)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();
    expect(find.text('RECS_SCREEN'), findsOneWidget);
  });

  testWidgets('every recommendation gets a card (no 6 cap)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(recs: () async => _tracks(20)));
    await tester.pumpAndSettle();

    expect(_cards(), findsNWidgets(20));
  });

  testWidgets('two rows filled column by column, equal-width cards', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(recs: () async => _tracks(8)));
    await tester.pumpAndSettle();

    final List<Rect> r = List<Rect>.generate(
      8,
      (int i) => tester.getRect(_cards().at(i)),
    );
    // Column 1: Song 0 on top of Song 1.
    expect(r[1].left, r[0].left);
    expect(r[1].top, greaterThan(r[0].bottom));
    // Column 2 starts at the top again, 10px gap to the right.
    expect(r[2].top, r[0].top);
    expect(r[2].left - r[0].right, closeTo(10, 0.01));
    // Only two rows.
    expect(r[3].top, r[1].top);
    expect(r[0].width, closeTo(r[7].width, 0.01));
  });

  testWidgets('three columns visible plus a peek of the fourth', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(recs: () async => _tracks(12)));
    await tester.pumpAndSettle();

    final double screen =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final Rect col1 = tester.getRect(_cards().at(0));
    final Rect col3 = tester.getRect(_cards().at(4));
    final Rect col4 = tester.getRect(_cards().at(6));
    expect(col1.left, 16);
    expect(col3.right, lessThan(screen));
    // Fourth column starts on screen but is cut off by the edge.
    expect(col4.left, lessThan(screen));
    expect(col4.right, greaterThan(screen));
    // 16 gutter + 3 cards + 3 gaps + 24px peek == screen width.
    expect(16 + col1.width * 3 + 30 + 24, closeTo(screen, 0.5));
  });

  testWidgets('slides sideways to reveal later recommendations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(recs: () async => _tracks(12)));
    await tester.pumpAndSettle();

    final double screen =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(tester.getRect(_cards().at(11)).left, greaterThan(screen));

    await tester.drag(_cards().first, const Offset(-2000, 0));
    await tester.pumpAndSettle();

    final Rect last = tester.getRect(_cards().at(11));
    expect(last.right, lessThanOrEqualTo(screen));
    expect(last.left, greaterThan(0));
  });

  testWidgets('refresh button beside the title fetches new recommendations', (
    WidgetTester tester,
  ) async {
    final _StubRecs stub = _StubRecs(() async => _tracks(3));
    await tester.pumpWidget(_wrap(recs: () async => _tracks(3), stub: stub));
    await tester.pumpAndSettle();

    final Finder button = find.byTooltip('New recommendations');
    expect(button, findsOneWidget);
    // Sits on the "For You" title line, to its right.
    final Rect title = tester.getRect(find.text('For You'));
    final Rect btn = tester.getRect(button);
    expect(btn.left, greaterThan(title.right));
    expect(btn.center.dy, closeTo(title.center.dy, 12));

    await tester.tap(button);
    await tester.pump();
    expect(stub.refreshCalls, 1);
  });

  testWidgets('card: #1C1C1C fill, 1px #2E2E2E border, 14px radius', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(recs: () async => _tracks(1)));
    await tester.pumpAndSettle();

    // The keyed card widget is the Material itself.
    final Material m = tester.widget<Material>(_cards().first);
    expect(m.color, const Color(0xFF1C1C1C));
    final RoundedRectangleBorder shape = m.shape! as RoundedRectangleBorder;
    expect(shape.side.color, const Color(0xFF2E2E2E));
    expect(shape.side.width, 1);
    expect(shape.borderRadius, BorderRadius.circular(14));
  });

  testWidgets('square art; 40px play button at its bottom-right', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(recs: () async => _tracks(1)));
    await tester.pumpAndSettle();

    final Rect art = tester.getRect(
      find.descendant(
        of: _cards().first,
        matching: find.byKey(const ValueKey<String>('for-you-art')),
      ),
    );
    expect(art.width, closeTo(art.height, 0.01));

    final Rect play = tester.getRect(find.byTooltip('Play Song 0'));
    expect(play.width, 40);
    expect(play.height, 40);
    expect(art.contains(play.center), isTrue);
    // Bottom-right quadrant, inset from the corner.
    expect(play.center.dx, greaterThan(art.center.dx));
    expect(play.center.dy, greaterThan(art.center.dy));
    expect(art.right - play.right, inInclusiveRange(4, 10));
    expect(art.bottom - play.bottom, inInclusiveRange(4, 10));
  });

  testWidgets('title and artist are single-line with an ellipsis', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        recs: () async => (<RecommendedTrack>[
          const RecommendedTrack(
            title: 'An extremely long recommended song title that cannot fit',
            artist: 'An artist name that is also far too long for a card',
            sourceUrl: 'https://music.youtube.com/watch?v=long',
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    for (final String s in <String>[
      'An extremely long recommended song title that cannot fit',
      'An artist name that is also far too long for a card',
    ]) {
      final Text t = tester.widget<Text>(find.text(s));
      expect(t.maxLines, 1);
      expect(t.overflow, TextOverflow.ellipsis);
    }
  });

  testWidgets('play button streams the song via the preview proxy', (
    WidgetTester tester,
  ) async {
    final _MockHandler handler = _MockHandler();
    when(() => handler.playSong(any())).thenAnswer((_) async {});
    await tester.pumpWidget(
      _wrap(recs: () async => _tracks(2), handler: handler),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Play Song 0'));
    await tester.pump();

    final MediaItem item =
        verify(() => handler.playSong(captureAny())).captured.single
            as MediaItem;
    expect(item.title, 'Song 0');
    expect(item.artist, 'Artist 0');
    expect(item.extras?['preview'], isTrue);
    expect(item.extras?['sourceUrl'], 'https://music.youtube.com/watch?v=v0');
  });
}
