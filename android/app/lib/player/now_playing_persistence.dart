// `prefer_initializing_formals` would force the public named constructor
// params to be private-prefixed (`_store`, `_debounce`, `_now`), leaking
// the internal names across the call site. Same pattern as
// `scrobble_controller.dart`.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/subsonic/song.dart';
import '../offline/local_uri.dart';
import '../providers/server_creds.dart';
import 'heerr_audio_handler.dart';
import 'now_playing_snapshot.dart';
import 'now_playing_store.dart';
import 'player_provider.dart';
import 'song_to_media_item.dart';

part 'now_playing_persistence.g.dart';

/// Default debounce window for autosave. Burst-y events (every track
/// change emits queue + mediaItem + playbackState back-to-back) collapse
/// into a single write.
const Duration _kDefaultDebounce = Duration(milliseconds: 500);

/// Builds the snapshot to persist. Called immediately at save time so the
/// returned snapshot reflects the latest state — never cache.
typedef NowPlayingSnapshotBuilder = NowPlayingSnapshot Function();

/// Plain-Dart orchestrator that keeps the on-disk Now Playing snapshot in
/// sync with the live audio handler. P1.
///
/// Save triggers:
///  - Any emission on the `trigger` stream wired via [start] schedules a
///    debounced save (default 500 ms).
///  - [flush] performs an immediate save (returns the write Future). The
///    shell scaffold calls this from the `AppLifecycleState.paused` hook
///    so the OS-may-kill-us scenario captures a fresh position.
///
/// Tests construct directly with a `StreamController` for [start.trigger]
/// and a synchronous `build` closure that returns whatever snapshot the
/// test wants. Production wires via [nowPlayingPersistenceProvider] which
/// fuses the handler's queue / mediaItem / playbackState streams.
class NowPlayingPersistence {
  NowPlayingPersistence({
    required NowPlayingStore store,
    Duration debounce = _kDefaultDebounce,
  })  : _store = store,
        _debounce = debounce;

  final NowPlayingStore _store;
  final Duration _debounce;

  StreamSubscription<dynamic>? _sub;
  Timer? _debounceTimer;
  NowPlayingSnapshotBuilder? _build;
  bool _disposed = false;
  // Chains writes so a debounce fire that's already in flight can never
  // overlap a `flush()` (or another fire) on the same tmp-file path in
  // `NowPlayingStore.save` — concurrent `save()` calls race the shared
  // `.tmp` rename and throw PathNotFoundException.
  Future<void> _pendingWrite = Future<void>.value();

  /// Wire to a change-trigger [trigger] + the snapshot [build] closure.
  /// Each event on [trigger] schedules a debounced save; [flush] uses
  /// [build] directly to capture the latest position synchronously.
  ///
  /// Idempotent: a second call replaces the previous subscription +
  /// builder. Use [dispose] to fully tear down.
  void start({
    required Stream<dynamic> trigger,
    required NowPlayingSnapshotBuilder build,
  }) {
    _sub?.cancel();
    _build = build;
    _sub = trigger.listen((_) => _scheduleSave());
  }

  void _scheduleSave() {
    if (_disposed) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      unawaited(_enqueueWrite());
    });
  }

  /// Force an immediate save, bypassing the debounce. Called from the
  /// app-pause lifecycle hook so we capture the latest position before
  /// the OS may kill the process.
  Future<void> flush() async {
    if (_disposed) return;
    _debounceTimer?.cancel();
    await _enqueueWrite();
  }

  /// Serializes writes behind [_pendingWrite] so a debounce fire already
  /// in flight can't overlap a `flush()` call.
  Future<void> _enqueueWrite() {
    final Future<void> next = _pendingWrite.then((_) => _writeSnapshot());
    _pendingWrite = next;
    return next;
  }

  Future<void> _writeSnapshot() async {
    final NowPlayingSnapshotBuilder? build = _build;
    if (build == null) return;
    final NowPlayingSnapshot snapshot;
    try {
      snapshot = build();
    } catch (e, st) {
      debugPrint('now_playing_persistence: builder threw: $e');
      debugPrintStack(stackTrace: st);
      return;
    }
    try {
      await _store.save(snapshot);
    } catch (e, st) {
      // Best-effort. Persistence errors should never break playback.
      debugPrint('now_playing_persistence: save failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _debounceTimer?.cancel();
    await _sub?.cancel();
    _sub = null;
    _build = null;
    // Wait for any write already chained onto `_pendingWrite` (the debounce
    // timer fired before dispose() was called) to actually finish. Without
    // this, a caller that tears down resources the write depends on right
    // after dispose() — e.g. a test deleting its temp directory — can race
    // NowPlayingStore.save()'s tmp-file rename against that teardown and
    // throw PathNotFoundException. Safe to await unconditionally: the timer
    // cancel + subscription cancel above guarantee no *new* write can join
    // the chain after this point, so this can only wait on writes already
    // in flight.
    await _pendingWrite;
  }
}

/// Production builder: takes a handler and returns a snapshot of its
/// current state. Public so the provider wiring stays a one-liner.
NowPlayingSnapshot buildSnapshotFromHandler(
  HeerrAudioHandler handler, {
  DateTime Function() now = DateTime.now,
}) {
  final List<MediaItem> queue = handler.queue.value;
  final List<Song> songs = <Song>[
    for (final MediaItem item in queue)
      if (songFromMediaItem(item) case final Song s) s,
  ];
  final int rawIndex = handler.playbackState.value.queueIndex ?? 0;
  final int clampedIndex =
      songs.isEmpty ? 0 : rawIndex.clamp(0, songs.length - 1);
  final Duration position = handler.player.position;
  return NowPlayingSnapshot(
    songs: songs,
    currentIndex: clampedIndex,
    positionMs: position.inMilliseconds,
    updatedAt: now().millisecondsSinceEpoch,
  );
}

/// Keep-alive provider for the runtime persistence orchestrator. Watched
/// by the root app widget for its side effect — `start(...)` wires the
/// save listeners on first access.
@Riverpod(keepAlive: true)
Future<NowPlayingPersistence> nowPlayingPersistence(
  NowPlayingPersistenceRef ref,
) async {
  final NowPlayingStore store = await ref.watch(nowPlayingStoreProvider.future);
  final HeerrAudioHandler handler = ref.watch(audioHandlerProvider);
  final NowPlayingPersistence persistence =
      NowPlayingPersistence(store: store);
  // Any of the three handler streams emitting is a save trigger. We
  // merge by listening to each separately and forwarding into one
  // controller; cheaper than pulling rxdart's Rx.merge for one call.
  final StreamController<void> trigger =
      StreamController<void>.broadcast();
  final List<StreamSubscription<dynamic>> subs = <StreamSubscription<dynamic>>[
    handler.queue.stream.listen((_) => trigger.add(null)),
    handler.mediaItem.stream.listen((_) => trigger.add(null)),
    handler.playbackState.stream.listen((_) => trigger.add(null)),
  ];
  persistence.start(
    trigger: trigger.stream,
    build: () => buildSnapshotFromHandler(handler),
  );
  ref.onDispose(() {
    for (final StreamSubscription<dynamic> s in subs) {
      unawaited(s.cancel());
    }
    unawaited(trigger.close());
    unawaited(persistence.dispose());
  });
  return persistence;
}

/// Cold-start queue restore. Runs once at app boot via a keep-alive
/// provider watched by [HeerrApp] for its side effect.
///
/// Flow:
///   1. Load the snapshot from disk. Null / empty / corrupt → no-op.
///   2. Resolve Navidrome creds + the offline manifest. Missing creds →
///      no-op (the songs would have no playable URI anyway; user goes
///      to Settings first).
///   3. For each [Song] in the snapshot, resolve a `localFilePath` via
///      the offline layer (chokepoint at `localUriForProvider`) — same
///      path `playback_actions.dart` uses to prefer-local over stream.
///   4. Build [MediaItem]s via [songToMediaItem] with **current** creds.
///      Auth salts rotate per process — never restore the old URLs.
///   5. Call [HeerrAudioHandler.restoreQueue] which sets the queue +
///      seeks but does **not** call `play()`. User taps to resume.
///
/// Failures throughout are caught and ignored — restore is best-effort,
/// not a play-blocking gate.
@Riverpod(keepAlive: true)
Future<void> nowPlayingRestore(NowPlayingRestoreRef ref) async {
  try {
    final NowPlayingStore store =
        await ref.read(nowPlayingStoreProvider.future);
    final NowPlayingSnapshot? snapshot = await store.load();
    if (snapshot == null || snapshot.songs.isEmpty) return;

    final ServerCreds settings = ref.read(serverCredsProvider);
    final String? baseUrl = settings.navidromeBaseUrl;
    final String? username = settings.navidromeUsername;
    final String? password = settings.navidromePassword;
    if (baseUrl == null || baseUrl.isEmpty ||
        username == null || username.isEmpty ||
        password == null || password.isEmpty) {
      return;
    }

    final List<MediaItem> items = <MediaItem>[];
    for (final Song song in snapshot.songs) {
      final String? localUri =
          await ref.read(localUriForProvider(song.id).future);
      String? localPath;
      if (localUri != null) {
        final Uri parsed = Uri.parse(localUri);
        if (parsed.scheme == 'file') {
          localPath = parsed.toFilePath();
        }
      }
      items.add(songToMediaItem(
        song: song,
        navidromeBaseUrl: baseUrl,
        navidromeUsername: username,
        navidromePassword: password,
        localFilePath: localPath,
      ));
    }

    final HeerrAudioHandler handler = ref.read(audioHandlerProvider);
    await handler.restoreQueue(
      items,
      currentIndex: snapshot.currentIndex,
      position: Duration(milliseconds: snapshot.positionMs),
    );
  } catch (e, st) {
    debugPrint('now_playing_persistence: restore failed: $e');
    debugPrintStack(stackTrace: st);
  }
}
