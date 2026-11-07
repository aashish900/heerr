import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api/api_error.dart';
import '../models/download_response.dart';
import '../models/recommended_track.dart';
import '../models/subsonic/playlist.dart';
import '../services/backend_service.dart';
import '../services/subsonic_library_service.dart';
import 'download.dart';
import 'download_to_playlist.dart';
import 'library/playlist_mutations.dart';

part 'mix_saver.g.dart';

/// Songs downloaded + awaited at once while saving a mix. The backend only
/// runs `DOWNLOAD_CONCURRENCY` (default 2) downloads at a time, so more
/// pipelines would only add `/status` polling.
const int _kParallel = 3;

const List<String> _kMonths = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Poll cadence + clock for [MixSaver]; overridden in tests.
typedef MixSaveTiming = ({
  Duration jobPoll,
  Duration naviPoll,
  int maxJobPolls,
  int maxNaviPolls,
  DateTime Function() now,
});

final Provider<MixSaveTiming> mixSaveTimingProvider = Provider<MixSaveTiming>(
  (Ref ref) => (
    jobPoll: const Duration(seconds: 2),
    naviPoll: const Duration(seconds: 5),
    maxJobPolls: 150, // ~5 min per song
    maxNaviPolls: 18, // ~90 s for Navidrome to index it
    now: DateTime.now,
  ),
);

/// Progress of one "Save as playlist" run.
@immutable
class MixSaveState {
  const MixSaveState({
    required this.playlistName,
    required this.total,
    this.resolved = 0,
    this.added = 0,
    this.failed = 0,
    this.done = false,
    this.error,
  });

  final String playlistName;
  final int total;

  /// Songs whose download finished one way or another.
  final int resolved;

  /// Songs added to the playlist (set when [done]).
  final int added;

  /// Songs that failed, timed out or never showed up in the library.
  final int failed;
  final bool done;

  /// Set when the run as a whole failed (playlist couldn't be created/filled).
  final String? error;

  MixSaveState copyWith({
    int? resolved,
    int? added,
    int? failed,
    bool? done,
    String? error,
  }) {
    return MixSaveState(
      playlistName: playlistName,
      total: total,
      resolved: resolved ?? this.resolved,
      added: added ?? this.added,
      failed: failed ?? this.failed,
      done: done ?? this.done,
      error: error ?? this.error,
    );
  }
}

/// "Save as playlist" for a vibe mix (Phase MX9), keyed by mix id. Kept alive
/// so leaving the mix screen doesn't cancel a multi-minute save.
///
/// 1. Create an empty Navidrome playlist `"<title> · <d MMM>"`.
/// 2. Download every song ([_kParallel] at a time) and wait for each to be
///    indexed ([waitForLibrarySong]).
/// 3. Add the songs that made it, **in mix order**, in one call.
///
/// ponytail: an app kill mid-save leaves an empty/partial playlist (downloads
/// still finish server-side); persist the pending list if that ever matters.
@Riverpod(keepAlive: true)
class MixSaver extends _$MixSaver {
  @override
  MixSaveState? build(String mixId) => null;

  /// No-op while a save of this mix is already running.
  Future<void> save({
    required String title,
    required List<RecommendedTrack> tracks,
  }) async {
    final MixSaveState? current = state;
    if ((current != null && !current.done) || tracks.isEmpty) return;

    final MixSaveTiming timing = ref.read(mixSaveTimingProvider);
    final DateTime now = timing.now();
    final String name = '$title · ${now.day} ${_kMonths[now.month - 1]}';
    state = MixSaveState(playlistName: name, total: tracks.length);

    final String playlistId;
    try {
      final Playlist created = await ref
          .read(playlistMutationsProvider.notifier)
          .createPlaylist(name: name);
      playlistId = created.id;
    } on ApiError {
      state = state!.copyWith(
        done: true,
        error: "Couldn't create the playlist",
      );
      return;
    }

    final BackendService backend = await ref.read(
      backendServiceProvider.future,
    );
    final SubsonicLibraryService library = await ref.read(
      subsonicLibraryServiceProvider.future,
    );
    final List<String?> songIds = List<String?>.filled(tracks.length, null);
    int next = 0;

    Future<void> worker() async {
      while (next < tracks.length) {
        final int i = next++;
        final RecommendedTrack track = tracks[i];
        String? songId;
        try {
          final DownloadResponse response = await ref
              .read(downloadDispatcherProvider.notifier)
              .dispatch(
                track.sourceUrl,
                sourceType: 'song',
                displayName: track.title,
              );
          final LibraryWait wait = await waitForLibrarySong(
            backend: backend,
            library: library,
            response: response,
            title: track.title,
            artist: track.artist,
            jobPollInterval: timing.jobPoll,
            naviPollInterval: timing.naviPoll,
            maxJobPolls: timing.maxJobPolls,
            maxNaviPolls: timing.maxNaviPolls,
          );
          songId = wait.songId;
        } on ApiError {
          songId = null;
        }
        songIds[i] = songId;
        final MixSaveState s = state!;
        state = s.copyWith(
          resolved: s.resolved + 1,
          failed: s.failed + (songId == null ? 1 : 0),
        );
      }
    }

    await Future.wait(<Future<void>>[
      for (int k = 0; k < math.min(_kParallel, tracks.length); k++) worker(),
    ]);

    final List<String> ordered = songIds.whereType<String>().toList();
    if (ordered.isNotEmpty) {
      try {
        await ref
            .read(playlistMutationsProvider.notifier)
            .addSongs(playlistId: playlistId, songIds: ordered);
      } on ApiError {
        state = state!.copyWith(
          done: true,
          error: "Downloaded, but couldn't add the songs to the playlist",
        );
        return;
      }
    }
    state = state!.copyWith(done: true, added: ordered.length);
  }
}
