import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../models/download_response.dart';
import '../models/enums.dart';
import '../models/search_result_item.dart';
import '../services/backend_service.dart';
import '../services/subsonic_library_service.dart';
import '../widgets/error_snackbar.dart';
import 'download.dart';
import 'library/playlist_mutations.dart';

/// U1: dispatch an online-search download and, once the backend job finishes
/// and Navidrome indexes the new file, add the resulting library song to
/// [playlistId]. Top-level async orchestration with no persistent Riverpod
/// state — mirrors `playPreview` / `playSongFromSubsonic`.
///
/// Flow (every `await` is guarded by `context.mounted`):
///   1. `POST /download` via [downloadDispatcherProvider]; show a
///      "Downloading…" snackbar. `ApiError` → [showApiError], return.
///   2. If the dispatch response isn't already terminal, poll
///      `BackendService.jobStatus` every [jobPollInterval] up to
///      [maxJobPolls]. `failed` → error snackbar, return. Timeout → snackbar,
///      return.
///   3. Poll `SubsonicLibraryService.findLibraryMatch("<title> <artist>")`
///      every [naviPollInterval] up to [maxNaviPolls]. Transient `ApiError`
///      keeps polling; a null match at the ceiling → warning snackbar, return.
///   4. `PlaylistMutations.addSongs(playlistId, [match.id])` → success
///      snackbar.
///
/// Steps 2–3 are [waitForLibrarySong] (context-free; MX9's mix saver reuses
/// it), with `context.mounted` as its keep-going check.
Future<void> downloadAndAddToPlaylist({
  required WidgetRef ref,
  required BuildContext context,
  required SearchResultItem item,
  required String playlistId,
  required String playlistName,
  @visibleForTesting Duration jobPollInterval = const Duration(seconds: 2),
  @visibleForTesting Duration naviPollInterval = const Duration(seconds: 5),
  @visibleForTesting int maxJobPolls = 150, // ~5 min ceiling
  @visibleForTesting int maxNaviPolls = 18, // ~90 s ceiling
}) async {
  // ----- Step 1: dispatch the download --------------------------------------
  final DownloadResponse response;
  try {
    response = await ref
        .read(downloadDispatcherProvider.notifier)
        .dispatch(
          item.sourceUrl,
          sourceType: item.sourceType,
          displayName: item.title,
        );
  } on ApiError catch (e) {
    if (!context.mounted) return;
    showApiError(context, e, action: 'download');
    return;
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: kSnackBarDuration,
      content: Text(
        "Downloading '${item.title}' — will add to '$playlistName' when ready",
      ),
    ),
  );

  // ----- Steps 2-3: wait for the job, then for Navidrome to index it -------
  final LibraryWait wait = await waitForLibrarySong(
    backend: await ref.read(backendServiceProvider.future),
    library: await ref.read(subsonicLibraryServiceProvider.future),
    response: response,
    title: item.title,
    artist: item.artist,
    keepGoing: () => context.mounted,
    jobPollInterval: jobPollInterval,
    naviPollInterval: naviPollInterval,
    maxJobPolls: maxJobPolls,
    maxNaviPolls: maxNaviPolls,
  );
  if (!context.mounted) return;
  final String? problem = switch (wait.outcome) {
    LibraryWaitOutcome.found || LibraryWaitOutcome.cancelled => null,
    LibraryWaitOutcome.timedOut =>
      "Download of '${item.title}' is taking too long",
    LibraryWaitOutcome.failed => "Download of '${item.title}' failed",
    LibraryWaitOutcome.notIndexed =>
      "Downloaded '${item.title}' but it's not indexed yet — "
          "add it to '$playlistName' manually",
  };
  if (problem != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(duration: kSnackBarErrorDuration, content: Text(problem)),
    );
    return;
  }
  if (wait.outcome == LibraryWaitOutcome.cancelled) return;
  final String songId = wait.songId!;

  // ----- Step 4: add to the playlist ----------------------------------------
  try {
    await ref
        .read(playlistMutationsProvider.notifier)
        .addSongs(playlistId: playlistId, songIds: <String>[songId]);
  } on ApiError catch (e) {
    if (!context.mounted) return;
    showApiError(context, e);
    return;
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: kSnackBarDuration,
      content: Text("Added '${item.title}' to '$playlistName'"),
    ),
  );
}

/// How [waitForLibrarySong] ended.
enum LibraryWaitOutcome {
  /// Downloaded and indexed — `songId` is the Navidrome song id.
  found,

  /// The backend job failed.
  failed,

  /// The job didn't reach a terminal state within `maxJobPolls`.
  timedOut,

  /// Downloaded, but Navidrome hadn't indexed it within `maxNaviPolls`.
  notIndexed,

  /// `keepGoing` returned false (e.g. the screen went away).
  cancelled,
}

typedef LibraryWait = ({LibraryWaitOutcome outcome, String? songId});

/// Steps 2–3 of a download-then-use flow, without UI: poll the backend job
/// (from [response]) until it's terminal, then poll Navidrome's `search3`
/// for `"<title> <artist>"` until the new file is indexed. Transient
/// [ApiError]s on either poll are retried until the ceiling.
Future<LibraryWait> waitForLibrarySong({
  required BackendService backend,
  required SubsonicLibraryService library,
  required DownloadResponse response,
  required String title,
  required String artist,
  bool Function()? keepGoing,
  Duration jobPollInterval = const Duration(seconds: 2),
  Duration naviPollInterval = const Duration(seconds: 5),
  int maxJobPolls = 150, // ~5 min ceiling
  int maxNaviPolls = 18, // ~90 s ceiling
}) async {
  bool go() => keepGoing?.call() ?? true;
  const LibraryWait cancelled = (
    outcome: LibraryWaitOutcome.cancelled,
    songId: null,
  );

  JobState jobState = response.state;
  if (!jobState.isTerminal) {
    bool resolved = false;
    for (int i = 0; i < maxJobPolls; i++) {
      if (!go()) return cancelled;
      await Future<void>.delayed(jobPollInterval);
      if (!go()) return cancelled;
      try {
        jobState = (await backend.jobStatus(response.jobId)).state;
      } on ApiError {
        continue; // transient — keep polling until the ceiling
      }
      if (jobState.isTerminal) {
        resolved = true;
        break;
      }
    }
    if (!resolved) {
      return (outcome: LibraryWaitOutcome.timedOut, songId: null);
    }
  }
  if (jobState == JobState.failed) {
    return (outcome: LibraryWaitOutcome.failed, songId: null);
  }

  for (int i = 0; i < maxNaviPolls; i++) {
    if (!go()) return cancelled;
    SubsonicSongMatch? match;
    try {
      match = await library.findLibraryMatch('$title $artist');
    } on ApiError {
      match = null; // Navidrome briefly unreachable / mid-scan
    }
    if (match != null) {
      return (outcome: LibraryWaitOutcome.found, songId: match.id);
    }
    if (i < maxNaviPolls - 1) {
      await Future<void>.delayed(naviPollInterval);
    }
  }
  return (outcome: LibraryWaitOutcome.notIndexed, songId: null);
}
