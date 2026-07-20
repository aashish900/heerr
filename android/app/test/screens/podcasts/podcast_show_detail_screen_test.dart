import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/models/enums.dart';
import 'package:heerr/models/episode_download_response.dart';
import 'package:heerr/models/episode_list_response.dart';
import 'package:heerr/models/podcast_channel.dart';
import 'package:heerr/models/podcast_episode.dart';
import 'package:heerr/models/profile.dart';
import 'package:heerr/player/heerr_audio_handler.dart';
import 'package:heerr/player/player_provider.dart';
import 'package:heerr/providers/profiles/active_profile.dart';
import 'package:heerr/screens/podcasts/podcast_show_detail_screen.dart';
import 'package:heerr/services/backend_service.dart';

class _FakeHandler extends Mock implements HeerrAudioHandler {}

class _FakePlayer extends Mock implements AudioPlayer {}

class _StubBackend extends BackendService {
  _StubBackend({
    this.channel,
    this.episodes = const <PodcastEpisode>[],
    this.total = 0,
    this.downloadError,
  }) : super(Dio());

  final PodcastChannel? channel;
  final List<PodcastEpisode> episodes;
  final int total;
  final Object? downloadError;
  int refreshCalls = 0;
  final List<String> downloadCalls = <String>[];
  final List<String> unsubscribeCalls = <String>[];
  final List<String?> sortsSeen = <String?>[];

  @override
  Future<List<PodcastChannel>> podcastSubscriptions() async =>
      channel == null ? const <PodcastChannel>[] : <PodcastChannel>[channel!];

  @override
  Future<EpisodeListResponse> podcastEpisodes(
    String channelId, {
    int limit = 20,
    int offset = 0,
    String? sort,
  }) async {
    sortsSeen.add(sort);
    return EpisodeListResponse(episodes: episodes, total: total);
  }

  @override
  Future<PodcastChannel> refreshPodcastChannel(String channelId) async {
    refreshCalls++;
    return channel ??
        PodcastChannel(id: channelId, feedUrl: 'https://a.com/f.xml', title: 'Show');
  }

  @override
  Future<EpisodeDownloadResponse> downloadPodcastEpisode(
    String episodeId,
  ) async {
    downloadCalls.add(episodeId);
    final Object? err = downloadError;
    if (err != null) throw err;
    return const EpisodeDownloadResponse(
      jobId: 'j1',
      state: JobState.queued,
      deduped: false,
    );
  }

  @override
  Future<void> unsubscribePodcast(String channelId) async {
    unsubscribeCalls.add(channelId);
  }
}

Profile _profile() => Profile(
      id: 'p1',
      displayName: 'Alice',
      heerrBaseUrl: 'http://h',
      heerrBearerToken: 't',
      navidromeBaseUrl: 'http://n',
      navidromeUsername: 'alice-nd',
      navidromePassword: 'pw',
      createdAt: DateTime.utc(2026),
      lastUsedAt: DateTime.utc(2026),
    );

Widget _wrap({
  required BackendService backend,
  String channelId = 'c1',
  HeerrAudioHandler? handler,
  Profile? profile,
}) {
  return ProviderScope(
    overrides: <Override>[
      backendServiceProvider.overrideWith((_) async => backend),
      if (handler != null) audioHandlerProvider.overrideWithValue(handler),
      if (profile != null) activeProfileProvider.overrideWithValue(profile),
    ],
    child: MaterialApp(home: PodcastShowDetailScreen(channelId: channelId)),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const MediaItem(id: '', title: ''));
    registerFallbackValue(Duration.zero);
  });

  const PodcastChannel channelA = PodcastChannel(
    id: 'c1',
    feedUrl: 'https://a.com/f.xml',
    title: 'Show A',
  );

  const PodcastChannel channelWithAuthor = PodcastChannel(
    id: 'c1',
    feedUrl: 'https://a.com/f.xml',
    title: 'Show A',
    author: 'Author X',
  );

  PodcastEpisode ep(
    String id, {
    bool played = false,
    bool downloaded = false,
    int positionS = 0,
    int? durationS,
    DateTime? publishedAt,
  }) =>
      PodcastEpisode(
        id: id,
        channelId: 'c1',
        guid: 'guid-$id',
        title: 'Episode $id',
        enclosureUrl: 'https://a.com/$id.mp3',
        downloaded: downloaded,
        positionS: positionS,
        played: played,
        durationS: durationS,
        publishedAt: publishedAt,
      );

  testWidgets('renders the channel title in the hero',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(backend: _StubBackend(channel: channelA)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Show A'), findsOneWidget);
  });

  testWidgets('hero shows author and episode count',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      backend: _StubBackend(
        channel: channelWithAuthor,
        episodes: <PodcastEpisode>[ep('1')],
        total: 1,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Author X • 1 episodes'), findsOneWidget);
  });

  testWidgets('renders an empty state when there are no episodes',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(backend: _StubBackend(channel: channelA)));
    await tester.pumpAndSettle();

    expect(find.text('No episodes yet'), findsOneWidget);
  });

  testWidgets('renders one row per episode with duration',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      backend: _StubBackend(
        channel: channelA,
        episodes: <PodcastEpisode>[ep('1', durationS: 90)],
        total: 1,
      ),
    ));
    await tester.pumpAndSettle();

    // The lone episode also surfaces as "Latest Episode" in the mini
    // section, so its title legitimately renders twice on this screen.
    expect(find.text('Episode 1'), findsWidgets);
    expect(find.text('1:30'), findsOneWidget);
  });

  testWidgets('shows a resume hint for a partially-played episode',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      backend: _StubBackend(
        channel: channelA,
        episodes: <PodcastEpisode>[ep('1', positionS: 65, durationS: 120)],
        total: 1,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Resume at 1:05'), findsOneWidget);
  });

  testWidgets('an in-progress episode shows a Continue Listening mini row',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      backend: _StubBackend(
        channel: channelA,
        episodes: <PodcastEpisode>[ep('1', positionS: 65, durationS: 120)],
        total: 1,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Continue Listening'), findsOneWidget);
  });

  testWidgets('shows a check mark for a played episode',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      backend: _StubBackend(
        channel: channelA,
        episodes: <PodcastEpisode>[ep('1', played: true)],
        total: 1,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('pull-to-refresh calls refreshPodcastChannel',
      (WidgetTester tester) async {
    final _StubBackend backend = _StubBackend(
      channel: channelA,
      episodes: <PodcastEpisode>[ep('1')],
      total: 1,
    );
    await tester.pumpWidget(_wrap(backend: backend));
    await tester.pumpAndSettle();

    final RefreshIndicator indicator =
        tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
    await indicator.onRefresh();
    await tester.pumpAndSettle();

    expect(backend.refreshCalls, 1);
  });

  testWidgets('a not-yet-downloaded episode shows a Download button',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      backend: _StubBackend(
        channel: channelA,
        episodes: <PodcastEpisode>[ep('1')],
        total: 1,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('podcast-episode-download-1')), findsOneWidget);
    expect(find.byIcon(Icons.download_done), findsNothing);
  });

  testWidgets('a downloaded episode shows a static badge, not a button',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      backend: _StubBackend(
        channel: channelA,
        episodes: <PodcastEpisode>[ep('1', downloaded: true)],
        total: 1,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.download_done), findsOneWidget);
    expect(find.byKey(const Key('podcast-episode-download-1')), findsNothing);
  });

  testWidgets(
      'tapping Download dispatches the episode download and shows a '
      'Queued snackbar', (WidgetTester tester) async {
    final _StubBackend backend = _StubBackend(
      channel: channelA,
      episodes: <PodcastEpisode>[ep('1')],
      total: 1,
    );
    await tester.pumpWidget(_wrap(backend: backend));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('podcast-episode-download-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(backend.downloadCalls, <String>['1']);
    expect(find.text('Queued: Episode 1'), findsOneWidget);
  });

  testWidgets('a download error shows the ApiError snackbar',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      backend: _StubBackend(
        channel: channelA,
        episodes: <PodcastEpisode>[ep('1')],
        total: 1,
        downloadError: const ForbiddenError(detail: 'no download scope'),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('podcast-episode-download-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // ForbiddenError + action:'download' renders the action-aware copy,
    // not the raw detail (see error_snackbar.dart::buildApiErrorSnackBar).
    expect(find.textContaining('this token cannot download'), findsOneWidget);
  });

  testWidgets('tapping an episode row plays it and seeks to its resume position',
      (WidgetTester tester) async {
    final _FakeHandler handler = _FakeHandler();
    final _FakePlayer player = _FakePlayer();
    when(() => handler.playSong(any())).thenAnswer((_) async {});
    when(() => handler.player).thenReturn(player);
    when(() => player.seek(any())).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(
      backend: _StubBackend(
        channel: channelA,
        episodes: <PodcastEpisode>[ep('1', positionS: 42)],
        total: 1,
      ),
      handler: handler,
      profile: _profile(),
    ));
    await tester.pumpAndSettle();

    // Keyed lookup, not find.text('Episode 1') — the title also renders in
    // the Continue Listening mini row for an in-progress episode.
    await tester.tap(find.byKey(const Key('podcast-episode-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    verify(() => handler.playSong(any())).called(1);
    verify(() => player.seek(const Duration(seconds: 42))).called(1);
    expect(find.text('Playing: Episode 1'), findsOneWidget);
  });

  testWidgets('tapping Continue plays the in-progress episode',
      (WidgetTester tester) async {
    final _FakeHandler handler = _FakeHandler();
    final _FakePlayer player = _FakePlayer();
    when(() => handler.playSong(any())).thenAnswer((_) async {});
    when(() => handler.player).thenReturn(player);
    when(() => player.seek(any())).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(
      backend: _StubBackend(
        channel: channelA,
        episodes: <PodcastEpisode>[ep('1', positionS: 10, durationS: 100)],
        total: 1,
      ),
      handler: handler,
      profile: _profile(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.byKey(const Key('podcast-show-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    verify(() => handler.playSong(any())).called(1);
  });

  testWidgets('Following toggle shows "Following" for a subscribed show '
      'and unsubscribes on tap', (WidgetTester tester) async {
    final _StubBackend backend = _StubBackend(channel: channelA);
    await tester.pumpWidget(_wrap(backend: backend));
    await tester.pumpAndSettle();

    expect(find.text('Following'), findsOneWidget);
    await tester.tap(find.byKey(const Key('podcast-show-following-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(backend.unsubscribeCalls, <String>['c1']);
  });

  testWidgets('About tab shows the channel description',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      backend: _StubBackend(
        channel: const PodcastChannel(
          id: 'c1',
          feedUrl: 'https://a.com/f.xml',
          title: 'Show A',
          description: 'A show about things.',
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();

    // Renders twice on this screen — once as the hero's description
    // snippet, once as the About tab's full body (TabBarView builds both
    // tab bodies up front, so both are present in the tree).
    expect(find.text('A show about things.'), findsNWidgets(2));
  });

  testWidgets('sort menu selects Oldest and reloads with sort=oldest',
      (WidgetTester tester) async {
    final _StubBackend backend = _StubBackend(
      channel: channelA,
      episodes: <PodcastEpisode>[ep('1')],
      total: 1,
    );
    await tester.pumpWidget(_wrap(backend: backend));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('podcast-episodes-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('podcast-episodes-sort-oldest')));
    await tester.pumpAndSettle();

    expect(backend.sortsSeen, <String?>[null, 'oldest']);
  });
}
