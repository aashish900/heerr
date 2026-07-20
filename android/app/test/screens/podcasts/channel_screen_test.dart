import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/episode_list_response.dart';
import 'package:heerr/models/podcast_channel.dart';
import 'package:heerr/models/podcast_episode.dart';
import 'package:heerr/screens/podcasts/channel_screen.dart';
import 'package:heerr/services/backend_service.dart';

class _StubBackend extends BackendService {
  _StubBackend({
    this.channel,
    this.episodes = const <PodcastEpisode>[],
    this.total = 0,
  }) : super(Dio());

  final PodcastChannel? channel;
  final List<PodcastEpisode> episodes;
  final int total;
  int refreshCalls = 0;

  @override
  Future<List<PodcastChannel>> podcastSubscriptions() async =>
      channel == null ? const <PodcastChannel>[] : <PodcastChannel>[channel!];

  @override
  Future<EpisodeListResponse> podcastEpisodes(
    String channelId, {
    int limit = 20,
    int offset = 0,
  }) async {
    return EpisodeListResponse(episodes: episodes, total: total);
  }

  @override
  Future<PodcastChannel> refreshPodcastChannel(String channelId) async {
    refreshCalls++;
    return channel ??
        PodcastChannel(id: channelId, feedUrl: 'https://a.com/f.xml', title: 'Show');
  }
}

Widget _wrap({required BackendService backend, String channelId = 'c1'}) {
  return ProviderScope(
    overrides: <Override>[
      backendServiceProvider.overrideWith((_) async => backend),
    ],
    child: MaterialApp(home: ChannelScreen(channelId: channelId)),
  );
}

void main() {
  const PodcastChannel channelA = PodcastChannel(
    id: 'c1',
    feedUrl: 'https://a.com/f.xml',
    title: 'Show A',
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

  testWidgets('renders the channel title as the app bar title',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(backend: _StubBackend(channel: channelA)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Show A'), findsOneWidget);
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

    expect(find.text('Episode 1'), findsOneWidget);
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
}
