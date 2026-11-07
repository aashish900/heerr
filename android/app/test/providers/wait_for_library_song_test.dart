import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/models/download_response.dart';
import 'package:heerr/models/enums.dart';
import 'package:heerr/models/job_view.dart';
import 'package:heerr/providers/download_to_playlist.dart';
import 'package:heerr/services/backend_service.dart';
import 'package:heerr/services/subsonic_library_service.dart';

/// Backend whose job walks through [states] (last one repeats); an entry of
/// null throws a transient ApiError for that poll.
class _Backend extends BackendService {
  _Backend(this.states) : super(Dio());
  final List<JobState?> states;
  int calls = 0;

  @override
  Future<JobView> jobStatus(String jobId) async {
    final JobState? s =
        states[calls < states.length ? calls : states.length - 1];
    calls++;
    if (s == null) throw const NetworkError();
    return JobView(
      jobId: jobId,
      sourceUrl: 'u',
      sourceType: ContentType.song,
      state: s,
      createdAt: DateTime.utc(2026, 11, 7),
    );
  }
}

/// Library that finds the song on the [foundOn]-th search (1-based); null
/// never finds it. [throwFirst] makes the first search a transient ApiError.
class _Library extends SubsonicLibraryService {
  _Library({this.foundOn, this.throwFirst = false}) : super(Dio());
  final int? foundOn;
  final bool throwFirst;
  final List<String> queries = <String>[];

  @override
  Future<SubsonicSongMatch?> findLibraryMatch(String query) async {
    queries.add(query);
    if (throwFirst && queries.length == 1) {
      throw const NetworkError();
    }
    return foundOn != null && queries.length >= foundOn!
        ? const SubsonicSongMatch(id: 'lib-9')
        : null;
  }
}

DownloadResponse _resp(JobState s) =>
    DownloadResponse(jobId: 'job-1', state: s, deduped: false);

Future<LibraryWait> _wait(
  _Backend backend,
  _Library library,
  DownloadResponse response, {
  bool Function()? keepGoing,
}) => waitForLibrarySong(
  backend: backend,
  library: library,
  response: response,
  title: 'Husn',
  artist: 'Anuv Jain',
  keepGoing: keepGoing ?? () => true,
  jobPollInterval: Duration.zero,
  naviPollInterval: Duration.zero,
  maxJobPolls: 5,
  maxNaviPolls: 3,
);

void main() {
  test(
    'queued → running → done, then indexed: found with the song id',
    () async {
      final _Backend backend = _Backend(<JobState?>[
        JobState.running,
        JobState.done,
      ]);
      final _Library library = _Library(foundOn: 2);
      final LibraryWait w = await _wait(
        backend,
        library,
        _resp(JobState.queued),
      );

      expect(w.outcome, LibraryWaitOutcome.found);
      expect(w.songId, 'lib-9');
      expect(backend.calls, 2);
      expect(library.queries.first, 'Husn Anuv Jain');
    },
  );

  test('already-terminal dispatch skips job polling', () async {
    final _Backend backend = _Backend(<JobState?>[JobState.running]);
    final LibraryWait w = await _wait(
      backend,
      _Library(foundOn: 1),
      _resp(JobState.done),
    );
    expect(w.outcome, LibraryWaitOutcome.found);
    expect(backend.calls, 0);
  });

  test('job failed → failed, library never searched', () async {
    final _Library library = _Library(foundOn: 1);
    final LibraryWait w = await _wait(
      _Backend(<JobState?>[JobState.failed]),
      library,
      _resp(JobState.queued),
    );
    expect(w.outcome, LibraryWaitOutcome.failed);
    expect(w.songId, isNull);
    expect(library.queries, isEmpty);
  });

  test('job never finishes → timedOut after maxJobPolls', () async {
    final _Backend backend = _Backend(<JobState?>[JobState.running]);
    final LibraryWait w = await _wait(
      backend,
      _Library(foundOn: 1),
      _resp(JobState.queued),
    );
    expect(w.outcome, LibraryWaitOutcome.timedOut);
    expect(backend.calls, 5);
  });

  test('transient job-status errors keep polling', () async {
    final LibraryWait w = await _wait(
      _Backend(<JobState?>[null, null, JobState.done]),
      _Library(foundOn: 1),
      _resp(JobState.queued),
    );
    expect(w.outcome, LibraryWaitOutcome.found);
  });

  test(
    'downloaded but never indexed → notIndexed after maxNaviPolls',
    () async {
      final _Library library = _Library();
      final LibraryWait w = await _wait(
        _Backend(<JobState?>[JobState.done]),
        library,
        _resp(JobState.done),
      );
      expect(w.outcome, LibraryWaitOutcome.notIndexed);
      expect(library.queries, hasLength(3));
    },
  );

  test('transient library errors keep polling', () async {
    final LibraryWait w = await _wait(
      _Backend(<JobState?>[JobState.done]),
      _Library(foundOn: 2, throwFirst: true),
      _resp(JobState.done),
    );
    expect(w.outcome, LibraryWaitOutcome.found);
  });

  test('keepGoing false stops waiting → cancelled', () async {
    final _Backend backend = _Backend(<JobState?>[JobState.running]);
    final LibraryWait w = await _wait(
      backend,
      _Library(foundOn: 1),
      _resp(JobState.queued),
      keepGoing: () => false,
    );
    expect(w.outcome, LibraryWaitOutcome.cancelled);
    expect(backend.calls, 0);
  });
}
