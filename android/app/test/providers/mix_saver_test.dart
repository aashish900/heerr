import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/models/download_response.dart';
import 'package:heerr/models/enums.dart';
import 'package:heerr/models/job_view.dart';
import 'package:heerr/models/recommended_track.dart';
import 'package:heerr/models/subsonic/playlist.dart';
import 'package:heerr/providers/download.dart';
import 'package:heerr/providers/library/playlist_mutations.dart';
import 'package:heerr/providers/mix_saver.dart';
import 'package:heerr/services/backend_service.dart';
import 'package:heerr/services/subsonic_library_service.dart';

RecommendedTrack _t(int i) => RecommendedTrack(
  title: 'Song $i',
  artist: 'Artist $i',
  sourceUrl: 'https://music.youtube.com/watch?v=v$i',
);

/// Every dispatch is "done" after [delayFor] (lets tests reorder completion);
/// [failUrls] come back as a failed job; tracks in-flight concurrency.
class _Dispatcher extends DownloadDispatcher {
  _Dispatcher({this.delayFor, this.failUrls = const <String>{}});
  final Duration Function(String url)? delayFor;
  final Set<String> failUrls;
  final List<String> urls = <String>[];
  int inFlight = 0;
  int maxInFlight = 0;

  @override
  Set<String> build() => const <String>{};

  @override
  Future<DownloadResponse> dispatch(
    String sourceUrl, {
    required String sourceType,
    String? displayName,
  }) async {
    urls.add(sourceUrl);
    inFlight++;
    maxInFlight = inFlight > maxInFlight ? inFlight : maxInFlight;
    await Future<void>.delayed(delayFor?.call(sourceUrl) ?? Duration.zero);
    inFlight--;
    return DownloadResponse(
      jobId: 'job-$sourceUrl',
      state: failUrls.contains(sourceUrl) ? JobState.failed : JobState.done,
      deduped: false,
    );
  }
}

class _Backend extends BackendService {
  _Backend() : super(Dio());

  @override
  Future<JobView> jobStatus(String jobId) async =>
      throw StateError('dispatch already returned a terminal state');
}

/// Finds "Song N Artist N" as lib-N, except titles in [unindexed].
class _Library extends SubsonicLibraryService {
  _Library({this.unindexed = const <String>{}}) : super(Dio());
  final Set<String> unindexed;

  @override
  Future<SubsonicSongMatch?> findLibraryMatch(String query) async {
    final RegExpMatch? m = RegExp(r'^Song (\d+) ').firstMatch(query);
    if (m == null || unindexed.contains('Song ${m[1]}')) return null;
    return SubsonicSongMatch(id: 'lib-${m[1]}');
  }
}

class _Mutations extends PlaylistMutations {
  _Mutations({this.failCreate = false});
  final bool failCreate;
  final List<String> created = <String>[];
  final List<(String, List<String>)> added = <(String, List<String>)>[];

  @override
  void build() {}

  @override
  Future<Playlist> createPlaylist({
    required String name,
    List<String> songIds = const <String>[],
  }) async {
    if (failCreate) throw const NetworkError();
    created.add(name);
    return Playlist(id: 'pl-new', name: name);
  }

  @override
  Future<int> addSongs({
    required String playlistId,
    required List<String> songIds,
  }) async {
    added.add((playlistId, List<String>.of(songIds)));
    return songIds.length;
  }
}

ProviderContainer _container({
  required _Dispatcher dispatcher,
  required _Mutations mutations,
  _Library? library,
}) {
  return ProviderContainer(
    overrides: <Override>[
      downloadDispatcherProvider.overrideWith(() => dispatcher),
      playlistMutationsProvider.overrideWith(() => mutations),
      backendServiceProvider.overrideWith((_) async => _Backend()),
      subsonicLibraryServiceProvider.overrideWith(
        (_) async => library ?? _Library(),
      ),
      mixSaveTimingProvider.overrideWithValue((
        jobPoll: Duration.zero,
        naviPoll: Duration.zero,
        maxJobPolls: 3,
        maxNaviPolls: 2,
        now: () => DateTime(2026, 11, 7, 21, 30),
      )),
    ],
  );
}

void main() {
  test(
    'creates "<title> · d MMM", downloads all, adds them in mix order',
    () async {
      // Song 0 is slowest, so completion order != mix order.
      final _Dispatcher dispatcher = _Dispatcher(
        delayFor: (String url) => url.endsWith('v0')
            ? const Duration(milliseconds: 40)
            : Duration.zero,
      );
      final _Mutations mutations = _Mutations();
      final ProviderContainer c = _container(
        dispatcher: dispatcher,
        mutations: mutations,
      );
      addTearDown(c.dispose);

      await c
          .read(mixSaverProvider('chill').notifier)
          .save(
            title: 'Chill Mix',
            tracks: List<RecommendedTrack>.generate(5, _t),
          );

      expect(mutations.created, <String>['Chill Mix · 7 Nov']);
      expect(dispatcher.urls.toSet(), <String>{
        for (int i = 0; i < 5; i++) 'https://music.youtube.com/watch?v=v$i',
      });
      // Records compare list fields by identity, so check the parts.
      expect(mutations.added, hasLength(1));
      expect(mutations.added.single.$1, 'pl-new');
      expect(mutations.added.single.$2, <String>[
        'lib-0',
        'lib-1',
        'lib-2',
        'lib-3',
        'lib-4',
      ]);
      final MixSaveState s = c.read(mixSaverProvider('chill'))!;
      expect(
        (s.done, s.total, s.resolved, s.added, s.failed, s.error),
        (true, 5, 5, 5, 0, null),
      );
      expect(s.playlistName, 'Chill Mix · 7 Nov');
    },
  );

  test(
    'failed and never-indexed songs are counted, the rest still added',
    () async {
      final _Dispatcher dispatcher = _Dispatcher(
        failUrls: <String>{'https://music.youtube.com/watch?v=v1'},
      );
      final _Mutations mutations = _Mutations();
      final ProviderContainer c = _container(
        dispatcher: dispatcher,
        mutations: mutations,
        library: _Library(unindexed: <String>{'Song 3'}),
      );
      addTearDown(c.dispose);

      await c
          .read(mixSaverProvider('chill').notifier)
          .save(
            title: 'Chill Mix',
            tracks: List<RecommendedTrack>.generate(4, _t),
          );

      expect(mutations.added.single.$2, <String>['lib-0', 'lib-2']);
      final MixSaveState s = c.read(mixSaverProvider('chill'))!;
      expect((s.done, s.added, s.failed), (true, 2, 2));
    },
  );

  test('progress counts up as songs resolve', () async {
    final _Dispatcher dispatcher = _Dispatcher();
    final ProviderContainer c = _container(
      dispatcher: dispatcher,
      mutations: _Mutations(),
    );
    addTearDown(c.dispose);
    final List<int> seen = <int>[];
    c.listen<MixSaveState?>(
      mixSaverProvider('chill'),
      (_, MixSaveState? s) => seen.add(s?.resolved ?? -1),
    );

    await c
        .read(mixSaverProvider('chill').notifier)
        .save(
          title: 'Chill Mix',
          tracks: List<RecommendedTrack>.generate(3, _t),
        );

    expect(seen.first, 0);
    expect(seen.where((int r) => r > 0).toSet(), <int>{1, 2, 3});
  });

  test('at most 3 songs in progress at once', () async {
    final _Dispatcher dispatcher = _Dispatcher(
      delayFor: (_) => const Duration(milliseconds: 5),
    );
    final ProviderContainer c = _container(
      dispatcher: dispatcher,
      mutations: _Mutations(),
    );
    addTearDown(c.dispose);

    await c
        .read(mixSaverProvider('chill').notifier)
        .save(
          title: 'Chill Mix',
          tracks: List<RecommendedTrack>.generate(10, _t),
        );

    expect(dispatcher.urls, hasLength(10));
    expect(dispatcher.maxInFlight, 3);
  });

  test('a second save while one is running is ignored', () async {
    final _Dispatcher dispatcher = _Dispatcher(
      delayFor: (_) => const Duration(milliseconds: 20),
    );
    final _Mutations mutations = _Mutations();
    final ProviderContainer c = _container(
      dispatcher: dispatcher,
      mutations: mutations,
    );
    addTearDown(c.dispose);
    final MixSaver saver = c.read(mixSaverProvider('chill').notifier);
    final List<RecommendedTrack> tracks = List<RecommendedTrack>.generate(
      2,
      _t,
    );

    final Future<void> first = saver.save(title: 'Chill Mix', tracks: tracks);
    await saver.save(title: 'Chill Mix', tracks: tracks);
    await first;

    expect(mutations.created, hasLength(1));
    expect(dispatcher.urls, hasLength(2));
  });

  test(
    'playlist creation failure ends with an error, nothing downloaded',
    () async {
      final _Dispatcher dispatcher = _Dispatcher();
      final ProviderContainer c = _container(
        dispatcher: dispatcher,
        mutations: _Mutations(failCreate: true),
      );
      addTearDown(c.dispose);

      await c
          .read(mixSaverProvider('chill').notifier)
          .save(
            title: 'Chill Mix',
            tracks: List<RecommendedTrack>.generate(2, _t),
          );

      final MixSaveState s = c.read(mixSaverProvider('chill'))!;
      expect(s.done, isTrue);
      expect(s.error, isNotNull);
      expect(dispatcher.urls, isEmpty);
    },
  );

  test('each mix saves independently', () async {
    final _Mutations mutations = _Mutations();
    final ProviderContainer c = _container(
      dispatcher: _Dispatcher(),
      mutations: mutations,
    );
    addTearDown(c.dispose);

    await c
        .read(mixSaverProvider('chill').notifier)
        .save(title: 'Chill Mix', tracks: <RecommendedTrack>[_t(0)]);
    expect(c.read(mixSaverProvider('party')), isNull);
  });
}
