import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/download_response.dart';
import 'package:heerr/models/enums.dart';
import 'package:heerr/models/job_view.dart';
import 'package:heerr/models/search_result_item.dart';
import 'package:heerr/providers/download.dart';
import 'package:heerr/providers/download_to_playlist.dart';
import 'package:heerr/providers/library/playlist_mutations.dart';
import 'package:heerr/services/backend_service.dart';
import 'package:heerr/services/subsonic_library_service.dart';

const SearchResultItem _item = SearchResultItem(
  sourceUrl: 'https://music.youtube.com/watch?v=abc',
  sourceType: 'song',
  title: 'Song',
  artist: 'Artist',
  alreadyDownloaded: false,
);

/// Dispatcher stub that returns a scripted [DownloadResponse].
class _StubDispatcher extends DownloadDispatcher {
  _StubDispatcher(this._response);
  final DownloadResponse _response;

  @override
  Set<String> build() => const <String>{};

  @override
  Future<DownloadResponse> dispatch(
    String sourceUrl, {
    required String sourceType,
    String? displayName,
  }) async {
    return _response;
  }
}

/// Backend stub — only [jobStatus] is exercised.
class _StubBackend extends BackendService {
  _StubBackend(this._job) : super(Dio());
  final JobView _job;

  @override
  Future<JobView> jobStatus(String jobId) async => _job;
}

/// Library stub — [findLibraryMatch] returns the scripted match (or null).
class _StubLibrary extends SubsonicLibraryService {
  _StubLibrary(this._match) : super(Dio());
  final SubsonicSongMatch? _match;

  @override
  Future<SubsonicSongMatch?> findLibraryMatch(String query) async => _match;
}

/// Records `addSongs` invocations.
class _StubMutations extends PlaylistMutations {
  static int addCalls = 0;
  static String? lastPlaylistId;
  static List<String>? lastSongIds;

  static void reset() {
    addCalls = 0;
    lastPlaylistId = null;
    lastSongIds = null;
  }

  @override
  void build() {}

  @override
  Future<int> addSongs({
    required String playlistId,
    required List<String> songIds,
  }) async {
    addCalls++;
    lastPlaylistId = playlistId;
    lastSongIds = List<String>.from(songIds);
    return songIds.length;
  }
}

JobView _failedJob() => JobView(
      jobId: 'job-1',
      sourceUrl: _item.sourceUrl,
      sourceType: ContentType.song,
      state: JobState.failed,
      createdAt: DateTime.utc(2026, 6, 24),
    );

Widget _host({
  required List<Override> overrides,
  int maxNaviPolls = 18,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(
          builder: (BuildContext context, WidgetRef ref, _) => Center(
            child: ElevatedButton(
              onPressed: () => downloadAndAddToPlaylist(
                ref: ref,
                context: context,
                item: _item,
                playlistId: 'pl-1',
                playlistName: 'Morning',
                jobPollInterval: const Duration(milliseconds: 10),
                naviPollInterval: const Duration(milliseconds: 10),
                maxNaviPolls: maxNaviPolls,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(_StubMutations.reset);
  tearDown(_StubMutations.reset);

  testWidgets(
    'happy path: done dispatch + library match → addSongs + success snackbar',
    (WidgetTester tester) async {
      await tester.pumpWidget(_host(overrides: <Override>[
        downloadDispatcherProvider.overrideWith(
          () => _StubDispatcher(const DownloadResponse(
            jobId: 'job-1',
            state: JobState.done,
            deduped: false,
          )),
        ),
        backendServiceProvider.overrideWith(
          (_) => Future<BackendService>.value(_StubBackend(_failedJob())),
        ),
        subsonicLibraryServiceProvider.overrideWith(
          (_) => Future<SubsonicLibraryService>.value(
            _StubLibrary(const SubsonicSongMatch(id: 'lib-1')),
          ),
        ),
        playlistMutationsProvider.overrideWith(_StubMutations.new),
      ]));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(_StubMutations.addCalls, 1);
      expect(_StubMutations.lastPlaylistId, 'pl-1');
      expect(_StubMutations.lastSongIds, <String>['lib-1']);
      expect(find.textContaining("Added 'Song' to 'Morning'"), findsOneWidget);
    },
  );

  testWidgets(
    'job failed → error snackbar, addSongs not called',
    (WidgetTester tester) async {
      await tester.pumpWidget(_host(overrides: <Override>[
        // Non-terminal dispatch → the job-status poll path runs.
        downloadDispatcherProvider.overrideWith(
          () => _StubDispatcher(const DownloadResponse(
            jobId: 'job-1',
            state: JobState.queued,
            deduped: false,
          )),
        ),
        backendServiceProvider.overrideWith(
          (_) => Future<BackendService>.value(_StubBackend(_failedJob())),
        ),
        subsonicLibraryServiceProvider.overrideWith(
          (_) => Future<SubsonicLibraryService>.value(
            _StubLibrary(const SubsonicSongMatch(id: 'lib-1')),
          ),
        ),
        playlistMutationsProvider.overrideWith(_StubMutations.new),
      ]));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(_StubMutations.addCalls, 0);
      expect(find.textContaining('failed'), findsOneWidget);
    },
  );

  testWidgets(
    'Navidrome timeout: match never appears → warning snackbar, no addSongs',
    (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        maxNaviPolls: 1,
        overrides: <Override>[
          downloadDispatcherProvider.overrideWith(
            () => _StubDispatcher(const DownloadResponse(
              jobId: 'job-1',
              state: JobState.done,
              deduped: false,
            )),
          ),
          backendServiceProvider.overrideWith(
            (_) => Future<BackendService>.value(_StubBackend(_failedJob())),
          ),
          subsonicLibraryServiceProvider.overrideWith(
            (_) => Future<SubsonicLibraryService>.value(_StubLibrary(null)),
          ),
          playlistMutationsProvider.overrideWith(_StubMutations.new),
        ],
      ));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.textContaining('not indexed yet'), findsOneWidget);
      expect(_StubMutations.addCalls, 0);
    },
  );
}
