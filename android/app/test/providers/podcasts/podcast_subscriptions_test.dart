import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/podcast_channel.dart';
import 'package:heerr/providers/podcasts/podcast_subscriptions.dart';
import 'package:heerr/services/backend_service.dart';

class _StubBackend extends BackendService {
  _StubBackend(this._initial) : super(Dio());
  final List<PodcastChannel> _initial;

  @override
  Future<List<PodcastChannel>> podcastSubscriptions() async =>
      List<PodcastChannel>.of(_initial);

  @override
  Future<PodcastChannel> subscribePodcast(String feedUrl) async {
    return PodcastChannel(id: 'new-id', feedUrl: feedUrl, title: 'New Show');
  }

  @override
  Future<void> unsubscribePodcast(String channelId) async {}
}

void main() {
  group('isFeedSubscribed / subscribedChannelFor', () {
    const List<PodcastChannel> subs = <PodcastChannel>[
      PodcastChannel(id: 'c1', feedUrl: 'https://a.com/f.xml', title: 'A'),
    ];

    test('isFeedSubscribed matches by feedUrl', () {
      expect(isFeedSubscribed(subs, 'https://a.com/f.xml'), isTrue);
      expect(isFeedSubscribed(subs, 'https://b.com/f.xml'), isFalse);
      expect(isFeedSubscribed(null, 'https://a.com/f.xml'), isFalse);
    });

    test('subscribedChannelFor returns the matching channel or null', () {
      expect(subscribedChannelFor(subs, 'https://a.com/f.xml')?.id, 'c1');
      expect(subscribedChannelFor(subs, 'https://b.com/f.xml'), isNull);
      expect(subscribedChannelFor(null, 'https://a.com/f.xml'), isNull);
    });
  });

  group('PodcastSubscriptions notifier', () {
    test('subscribe() prepends the ingested channel to state', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          backendServiceProvider.overrideWith(
            (_) async => _StubBackend(const <PodcastChannel>[]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(podcastSubscriptionsProvider.future);
      final PodcastChannel result = await container
          .read(podcastSubscriptionsProvider.notifier)
          .subscribe('https://new.com/f.xml');

      expect(result.id, 'new-id');
      final List<PodcastChannel> state =
          container.read(podcastSubscriptionsProvider).valueOrNull ??
              const <PodcastChannel>[];
      expect(state, hasLength(1));
      expect(state.single.feedUrl, 'https://new.com/f.xml');
    });

    test('unsubscribe() removes the channel from state', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          backendServiceProvider.overrideWith(
            (_) async => _StubBackend(const <PodcastChannel>[
              PodcastChannel(
                id: 'c1',
                feedUrl: 'https://a.com/f.xml',
                title: 'A',
              ),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(podcastSubscriptionsProvider.future);
      await container.read(podcastSubscriptionsProvider.notifier).unsubscribe('c1');

      final List<PodcastChannel> state =
          container.read(podcastSubscriptionsProvider).valueOrNull ??
              const <PodcastChannel>[];
      expect(state, isEmpty);
    });
  });
}
