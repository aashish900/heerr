import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/enums.dart';
import '../../models/job_view.dart';
import '../../models/queue_response.dart';
import '../../models/search_response.dart';
import '../../models/subsonic/search_result3.dart';
import '../queue.dart';
import '../search.dart';
import 'library_search.dart';

part 'combined_search.g.dart';

/// Grace period between observing a job's `done` transition in
/// [queueProvider] and re-fetching [librarySearchProvider]. Gives Navidrome
/// time to re-index the freshly-written `.mp3`. Exposed as a provider so
/// tests can shrink it.
const Duration kReindexGrace = Duration(seconds: 60);

@Riverpod(keepAlive: true)
Duration reindexGrace(ReindexGraceRef ref) => kReindexGrace;

/// Set of queries the user has explicitly opted into firing a YouTube-Music
/// search for. Auto-fire (when the library result is empty) bypasses this;
/// this set is only consulted when the library half *did* return results
/// and the user tapped "Search more on YouTube Music".
@Riverpod(keepAlive: true)
class YtmManualTrigger extends _$YtmManualTrigger {
  @override
  Set<String> build() => const <String>{};

  void trigger(String query) {
    if (query.trim().isEmpty) return;
    state = <String>{...state, query};
  }

  bool isTriggered(String query) => state.contains(query);

  void clearAll() {
    state = const <String>{};
  }
}

/// Result of a combined library + YouTube-Music search. The UI renders both
/// halves; this class is just the bag.
///
/// `ytm == null` means the YT half hasn't been fired for this query — the
/// UI should render the "Search more on YouTube Music" button instead.
class CombinedSearchResult {
  const CombinedSearchResult({
    required this.query,
    required this.library,
    this.ytm,
  });

  final String query;
  final AsyncValue<SearchResult3> library;
  final AsyncValue<SearchResponse>? ytm;

  bool get libraryHasData => library.hasValue;

  bool get libraryIsEmpty {
    final SearchResult3? r = library.valueOrNull;
    if (r == null) return false;
    return r.artist.isEmpty && r.album.isEmpty && r.song.isEmpty;
  }

  bool get libraryHasResults {
    final SearchResult3? r = library.valueOrNull;
    if (r == null) return false;
    return r.artist.isNotEmpty || r.album.isNotEmpty || r.song.isNotEmpty;
  }
}

/// Orchestrates the two search sources behind the Library tab's search field.
///
/// Behaviour:
///   1. Always fires [librarySearchProvider(query)] (the Subsonic side).
///   2. Fires [ytmSearchProvider(query)] when either:
///      a. the library half came back empty (auto-fire), or
///      b. the user explicitly opted in via [ytmManualTriggerProvider].
///   3. Subscribes to [queueProvider] for the duration of the search and,
///      whenever a job transitions to `done`, schedules a one-shot
///      [librarySearchProvider(query)] invalidation [kReindexGrace] later so
///      a freshly-downloaded track auto-promotes from the YT section into
///      the library section.
///
/// `keepAlive: false` (default) — when the user navigates away from the
/// search results, the in-flight timers and queue subscription tear down
/// automatically.
@riverpod
CombinedSearchResult combinedSearch(CombinedSearchRef ref, String query) {
  // -----------------------------------------------------------------
  // Reactive promotion: watch queueProvider for new done transitions.
  // -----------------------------------------------------------------
  final Set<String> seenDoneJobIds = <String>{};
  // Seed with whatever's already done at subscription time so we don't fire
  // a 60s timer for jobs that finished before the user even searched.
  final QueueResponse? initial = ref.read(queueProvider).valueOrNull;
  if (initial != null) {
    for (final JobView j in initial.recent) {
      if (j.state == JobState.done) seenDoneJobIds.add(j.jobId);
    }
    for (final JobView j in initial.active) {
      if (j.state == JobState.done) seenDoneJobIds.add(j.jobId);
    }
  }

  // Timers are intentionally NOT stored for cancellation. ref.onDispose fires
  // on every reactive rebuild (e.g. when ytmSearchProvider resolves), so
  // cancelling in onDispose would silently abort a pending promotion timer.
  // On true disposal the timer fires a harmless invalidate against an
  // already-dead auto-dispose provider; the try-catch guards that path.
  ref.listen<AsyncValue<QueueResponse>>(queueProvider, (
    AsyncValue<QueueResponse>? prev,
    AsyncValue<QueueResponse> next,
  ) {
    final QueueResponse? r = next.valueOrNull;
    if (r == null) return;
    final Iterable<JobView> allDone = <JobView>[
      ...r.active,
      ...r.recent,
    ].where((JobView j) => j.state == JobState.done);
    // AsyncLoading → AsyncData is the initial queue resolution, not a new
    // transition. Seed seenDoneJobIds so we don't schedule a spurious
    // promotion timer for jobs that were already done when the search opened.
    if (prev?.hasValue != true) {
      for (final JobView j in allDone) {
        seenDoneJobIds.add(j.jobId);
      }
      return;
    }
    final Set<String> newlyDone = <String>{};
    for (final JobView j in allDone) {
      if (seenDoneJobIds.add(j.jobId)) {
        newlyDone.add(j.jobId);
      }
    }
    if (newlyDone.isEmpty) return;
    final Duration grace = ref.read(reindexGraceProvider);
    Timer(grace, () {
      try {
        ref.invalidate(librarySearchProvider(query));
      } catch (_) {
        // combinedSearch was disposed before the grace period elapsed.
      }
    });
  });

  // -----------------------------------------------------------------
  // Source providers.
  // -----------------------------------------------------------------
  final AsyncValue<SearchResult3> library =
      ref.watch(librarySearchProvider(query));

  final SearchResult3? libValue = library.valueOrNull;
  final bool libraryEmpty = libValue != null &&
      libValue.artist.isEmpty &&
      libValue.album.isEmpty &&
      libValue.song.isEmpty;
  final bool manuallyTriggered = ref.watch(
    ytmManualTriggerProvider.select((Set<String> s) => s.contains(query)),
  );

  // Auto-fire YT only after the library half has resolved as empty.
  // (If library is still loading, we don't pre-fire YT — we wait so we
  // don't burn YouTube-Music quota on every keystroke that's about to land
  // in the local library.)
  final bool shouldFireYtm =
      query.trim().isNotEmpty && (libraryEmpty || manuallyTriggered);

  final AsyncValue<SearchResponse>? ytm =
      shouldFireYtm ? ref.watch(ytmSearchProvider(query)) : null;

  return CombinedSearchResult(query: query, library: library, ytm: ytm);
}
