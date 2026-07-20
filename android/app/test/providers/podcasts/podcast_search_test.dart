import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/podcast_channel.dart';
import 'package:heerr/providers/podcasts/podcast_search.dart';
import 'package:heerr/providers/search.dart';
import 'package:heerr/services/backend_service.dart';

class _StubBackend extends BackendService {
  _StubBackend(this._results) : super(Dio());
  final List<PodcastChannel> _results;
  final List<String> queries = <String>[];

  @override
  Future<List<PodcastChannel>> searchPodcasts(
    String query, {
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    queries.add(query);
    return _results;
  }
}

void main() {
  test('empty query short-circuits without calling the backend', () async {
    final _StubBackend backend = _StubBackend(const <PodcastChannel>[]);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        searchDebounceProvider.overrideWithValue(Duration.zero),
        backendServiceProvider.overrideWith((_) async => backend),
      ],
    );
    addTearDown(container.dispose);

    final List<PodcastChannel> result =
        await container.read(podcastSearchProvider('   ').future);

    expect(result, isEmpty);
    expect(backend.queries, isEmpty);
  });

  test('non-empty query calls the backend and returns results', () async {
    const PodcastChannel show =
        PodcastChannel(feedUrl: 'https://a.com/f.xml', title: 'Show A');
    final _StubBackend backend = _StubBackend(const <PodcastChannel>[show]);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        searchDebounceProvider.overrideWithValue(Duration.zero),
        backendServiceProvider.overrideWith((_) async => backend),
      ],
    );
    addTearDown(container.dispose);

    final List<PodcastChannel> result =
        await container.read(podcastSearchProvider('test').future);

    expect(result, <PodcastChannel>[show]);
    expect(backend.queries, <String>['test']);
  });
}
