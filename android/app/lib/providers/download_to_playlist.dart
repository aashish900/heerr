import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../models/download_response.dart';
import '../models/enums.dart';
import '../models/job_view.dart';
import '../models/search_result_item.dart';
import '../services/backend_service.dart';
import '../services/subsonic_library_service.dart';
import '../widgets/error_snackbar.dart';
import 'download.dart';
import 'library/playlist_mutations.dart';

/// U1: dispatch a YouTube-Music download and, once the backend job finishes
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
    response = await ref.read(downloadDispatcherProvider.notifier).dispatch(
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

  // ----- Step 2: wait for the job to finish ---------------------------------
  JobState jobState = response.state;
  if (!jobState.isTerminal) {
    final BackendService backend = await ref.read(backendServiceProvider.future);
    jobState = JobState.queued;
    bool resolved = false;
    for (int i = 0; i < maxJobPolls; i++) {
      await Future<void>.delayed(jobPollInterval);
      if (!context.mounted) return;
      try {
        final JobView job = await backend.jobStatus(response.jobId);
        jobState = job.state;
      } on ApiError {
        // Transient — keep polling until the ceiling.
        continue;
      }
      if (jobState.isTerminal) {
        resolved = true;
        break;
      }
    }
    if (!resolved && !jobState.isTerminal) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: kSnackBarErrorDuration,
          content: Text("Download of '${item.title}' is taking too long"),
        ),
      );
      return;
    }
  }

  if (jobState == JobState.failed) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: kSnackBarErrorDuration,
        content: Text("Download of '${item.title}' failed"),
      ),
    );
    return;
  }

  // ----- Step 3: wait for Navidrome to index the new file -------------------
  final SubsonicLibraryService library =
      await ref.read(subsonicLibraryServiceProvider.future);
  final String query = '${item.title} ${item.artist}';
  SubsonicSongMatch? match;
  for (int i = 0; i < maxNaviPolls; i++) {
    if (!context.mounted) return;
    try {
      match = await library.findLibraryMatch(query);
    } on ApiError {
      // Navidrome briefly unreachable / mid-scan — keep polling.
      match = null;
    }
    if (match != null) break;
    if (i < maxNaviPolls - 1) {
      await Future<void>.delayed(naviPollInterval);
    }
  }

  if (match == null) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: kSnackBarErrorDuration,
        content: Text(
          "Downloaded '${item.title}' but it's not indexed yet — "
          "add it to '$playlistName' manually",
        ),
      ),
    );
    return;
  }

  // ----- Step 4: add to the playlist ----------------------------------------
  try {
    await ref.read(playlistMutationsProvider.notifier).addSongs(
      playlistId: playlistId,
      songIds: <String>[match.id],
    );
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
