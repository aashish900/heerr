import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/client.dart';
import 'package:heerr/api/subsonic_client.dart';
import 'package:heerr/models/job_view.dart';
import 'package:heerr/models/queue_response.dart';
import 'package:heerr/models/search_response.dart';
import 'package:heerr/providers/library/combined_search.dart';
import 'package:heerr/providers/queue.dart';
import 'package:heerr/providers/search.dart';

// ---------------------------------------------------------------------------
// Stub queue. Lets a test seed the initial state and emit new states to
// simulate the poller landing transitions, without standing up a real
// backend.
// ---------------------------------------------------------------------------
class _StubQueue extends Queue {
  _StubQueue(this._initial);
  final QueueResponse _initial;

  @override
  Future<QueueResponse> build() async => _initial;

  void emit(AsyncValue<QueueResponse> next) {
    state = next;
  }
}

const QueueResponse _kEmptyQueue =
    QueueResponse(active: <JobView>[], recent: <JobView>[]);

// ---------------------------------------------------------------------------
// Split HTTP adapter — routes by URL path so a single ProviderContainer can
// stand in for two real dio instances (heerr + Subsonic/Navidrome). Any
// request hitting `/rest/search3.view` goes to the subsonic responder; every
// other path goes to the heerr responder.
// ---------------------------------------------------------------------------
class _SplitAdapter implements HttpClientAdapter {
  _SplitAdapter({required this.subsonic, required this.heerr});
  final FutureOr<ResponseBody> Function(RequestOptions options) subsonic;
  final FutureOr<ResponseBody> Function(RequestOptions options) heerr;
  final List<RequestOptions> subsonicRequests = <RequestOptions>[];
  final List<RequestOptions> heerrRequests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    if (options.path.contains('search3.view')) {
      subsonicRequests.add(options);
      return subsonic(options);
    }
    heerrRequests.add(options);
    return heerr(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: <String, List<String>>{
      'content-type': <String>['application/json'],
    },
  );
}

Map<String, dynamic> _subsonicSearch3Empty() => <String, dynamic>{
      'subsonic-response': <String, dynamic>{
        'status': 'ok',
        'version': '1.16.1',
        'searchResult3': <String, dynamic>{},
      },
    };

Map<String, dynamic> _subsonicSearch3WithHit() => <String, dynamic>{
      'subsonic-response': <String, dynamic>{
        'status': 'ok',
        'version': '1.16.1',
        'searchResult3': <String, dynamic>{
          'song': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'so-1',
              'title': 'Let It Happen',
              'artist': 'Tame Impala',
            },
          ],
        },
      },
    };

Map<String, dynamic> _ytmSearchPayload({String title = 'Let It Happen'}) =>
    <String, dynamic>{
      'results': <Map<String, dynamic>>[
        <String, dynamic>{
          'source_url': 'https://music.youtube.com/watch?v=xyz',
          'source_type': 'song',
          'title': title,
          'artist': 'Tame Impala',
          'already_downloaded': false,
        },
      ],
    };

class _Setup {
  _Setup({
    required this.adapter,
    required this.container,
    required this.queue,
  });
  final _SplitAdapter adapter;
  final ProviderContainer container;
  final _StubQueue queue;
}

/// Build a container wired up with:
/// - heerr dio + subsonic dio routed through a [_SplitAdapter]
/// - a stubbed queue provider (defaults to empty; override via [initialQueue])
/// - searchDebounce overridden to zero
/// - reindexGrace overridden so promotion tests don't pay 60s
_Setup _setup({
  ResponseBody Function(RequestOptions options)? subsonicResponder,
  ResponseBody Function(RequestOptions options)? heerrResponder,
  QueueResponse initialQueue = _kEmptyQueue,
  Duration reindexGrace = const Duration(milliseconds: 50),
}) {
  final _SplitAdapter adapter = _SplitAdapter(
    subsonic: subsonicResponder ?? (_) => _json(_subsonicSearch3Empty()),
    heerr: heerrResponder ?? (_) => _json(_ytmSearchPayload()),
  );

  final Dio heerrDio = Dio(BaseOptions(baseUrl: 'http://heerr.test/api/v1'));
  heerrDio.httpClientAdapter = adapter;
  final Dio subsonicDio = Dio(BaseOptions(baseUrl: 'http://navi.test'));
  subsonicDio.httpClientAdapter = adapter;

  final _StubQueue stubQueue = _StubQueue(initialQueue);

  final ProviderContainer c = ProviderContainer(
    overrides: <Override>[
      dioClientProvider.overrideWith((_) => heerrDio),
      subsonicDioClientProvider.overrideWith((_) async => subsonicDio),
      searchDebounceProvider.overrideWithValue(Duration.zero),
      reindexGraceProvider.overrideWithValue(reindexGrace),
      queueProvider.overrideWith(() => stubQueue),
    ],
  );
  return _Setup(adapter: adapter, container: c, queue: stubQueue);
}

/// Wait until [pred] is true on the combined-search state for [query], or
/// throw via the test framework if it never settles. Uses small fixed-step
/// polling so the test doesn't deadlock when the state stays stuck.
Future<CombinedSearchResult> _settle(
  ProviderContainer c,
  String query,
  bool Function(CombinedSearchResult r) pred, {
  Duration step = const Duration(milliseconds: 5),
  int maxSteps = 200,
}) async {
  for (int i = 0; i < maxSteps; i++) {
    final CombinedSearchResult r = c.read(combinedSearchProvider(query));
    if (pred(r)) return r;
    await Future<void>.delayed(step);
  }
  fail('combinedSearchProvider("$query") never satisfied predicate');
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ytmManualTriggerProvider', () {
    test('starts empty; trigger adds a query; isTriggered checks membership',
        () {
      final ProviderContainer c = ProviderContainer();
      addTearDown(c.dispose);

      expect(c.read(ytmManualTriggerProvider), isEmpty);
      c.read(ytmManualTriggerProvider.notifier).trigger('q1');
      expect(c.read(ytmManualTriggerProvider), <String>{'q1'});
      expect(
        c.read(ytmManualTriggerProvider.notifier).isTriggered('q1'),
        isTrue,
      );
      expect(
        c.read(ytmManualTriggerProvider.notifier).isTriggered('q2'),
        isFalse,
      );
    });

    test('whitespace-only triggers are ignored', () {
      final ProviderContainer c = ProviderContainer();
      addTearDown(c.dispose);

      c.read(ytmManualTriggerProvider.notifier).trigger('   ');
      expect(c.read(ytmManualTriggerProvider), isEmpty);
    });
  });

  group('combinedSearchProvider — auto-fire / manual button', () {
    test('library has results → YT does NOT auto-fire (button shown)',
        () async {
      final _Setup s = _setup(
        subsonicResponder: (_) => _json(_subsonicSearch3WithHit()),
      );
      addTearDown(s.container.dispose);

      // Keep combinedSearch alive across the awaits.
      s.container.listen<CombinedSearchResult>(
        combinedSearchProvider('tame'),
        (_, _) {},
      );

      final CombinedSearchResult r = await _settle(
        s.container,
        'tame',
        (CombinedSearchResult r) => r.libraryHasResults,
      );

      // Give the orchestrator a beat in case it would have decided to fire.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final CombinedSearchResult r2 =
          s.container.read(combinedSearchProvider('tame'));

      expect(r.library.hasValue, isTrue);
      expect(r2.ytm, isNull, reason: 'YT must not auto-fire when library hits');
      expect(s.adapter.heerrRequests, isEmpty);
    });

    test('library is empty → YT auto-fires', () async {
      final _Setup s = _setup(
        heerrResponder: (_) => _json(_ytmSearchPayload(title: 'YT Hit')),
      );
      addTearDown(s.container.dispose);

      s.container.listen<CombinedSearchResult>(
        combinedSearchProvider('q'),
        (_, _) {},
      );

      final CombinedSearchResult r = await _settle(
        s.container,
        'q',
        (CombinedSearchResult r) =>
            r.libraryIsEmpty &&
            r.ytm != null &&
            r.ytm!.hasValue,
      );

      expect(r.libraryIsEmpty, isTrue);
      expect(r.ytm, isNotNull);
      final SearchResponse ytm = r.ytm!.requireValue;
      expect(ytm.results, hasLength(1));
      expect(ytm.results.first.title, 'YT Hit');
      expect(s.adapter.heerrRequests, hasLength(1));
    });

    test('manual trigger fires YT even when library has results', () async {
      final _Setup s = _setup(
        subsonicResponder: (_) => _json(_subsonicSearch3WithHit()),
      );
      addTearDown(s.container.dispose);

      s.container.listen<CombinedSearchResult>(
        combinedSearchProvider('tame'),
        (_, _) {},
      );

      // Wait for the library half to settle with hits, and confirm YT not fired.
      await _settle(
        s.container,
        'tame',
        (CombinedSearchResult r) => r.libraryHasResults,
      );
      expect(s.adapter.heerrRequests, isEmpty);

      // User taps the manual button.
      s.container
          .read(ytmManualTriggerProvider.notifier)
          .trigger('tame');

      await _settle(
        s.container,
        'tame',
        (CombinedSearchResult r) => r.ytm != null && r.ytm!.hasValue,
      );

      expect(s.adapter.heerrRequests, hasLength(1));
    });

    test('empty / whitespace query never fires YT (no quota burn)',
        () async {
      final _Setup s = _setup();
      addTearDown(s.container.dispose);

      s.container.listen<CombinedSearchResult>(
        combinedSearchProvider(''),
        (_, _) {},
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final CombinedSearchResult r =
          s.container.read(combinedSearchProvider(''));
      expect(r.ytm, isNull);
      expect(s.adapter.heerrRequests, isEmpty);
    });
  });

  group('combinedSearchProvider — reactive promotion', () {
    test(
        'new done transition in queue invalidates librarySearchProvider after '
        'reindex grace', () async {
      int subsonicFetches = 0;
      final _Setup s = _setup(
        subsonicResponder: (_) {
          subsonicFetches++;
          return _json(_subsonicSearch3Empty());
        },
      );
      addTearDown(s.container.dispose);

      s.container.listen<CombinedSearchResult>(
        combinedSearchProvider('q'),
        (_, _) {},
      );

      // Wait until the library half (and YT auto-fire) settles.
      await _settle(
        s.container,
        'q',
        (CombinedSearchResult r) => r.libraryIsEmpty,
      );
      final int baseline = subsonicFetches;
      expect(baseline, greaterThanOrEqualTo(1));

      // Simulate the queue poller landing a new done job.
      s.queue.emit(
        AsyncData<QueueResponse>(
          QueueResponse(
            active: const <JobView>[],
            recent: <JobView>[_doneJob('job-1')],
          ),
        ),
      );

      // Wait past the reindex grace + library re-fetch.
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(
        subsonicFetches,
        greaterThan(baseline),
        reason:
            'librarySearchProvider should have been invalidated after grace',
      );
    });

    test(
        'jobs already done at subscription time do NOT schedule a promotion',
        () async {
      int subsonicFetches = 0;
      final _Setup s = _setup(
        subsonicResponder: (_) {
          subsonicFetches++;
          return _json(_subsonicSearch3Empty());
        },
        initialQueue: QueueResponse(
          active: const <JobView>[],
          recent: <JobView>[_doneJob('seed-job')],
        ),
      );
      addTearDown(s.container.dispose);

      s.container.listen<CombinedSearchResult>(
        combinedSearchProvider('q'),
        (_, _) {},
      );

      await _settle(
        s.container,
        'q',
        (CombinedSearchResult r) => r.libraryIsEmpty,
      );
      final int baseline = subsonicFetches;

      // Wait past grace; nothing new emitted.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(
        subsonicFetches,
        baseline,
        reason: 'seed-done jobs should be skipped (no transition)',
      );
    });
  });
}

JobView _doneJob(String jobId) {
  return JobView.fromJson(<String, dynamic>{
    'job_id': jobId,
    'source_url': 'https://music.youtube.com/watch?v=$jobId',
    'source_type': 'song',
    'state': 'done',
    'created_at': '2026-06-11T00:00:00Z',
  });
}
