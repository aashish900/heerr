import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

/// The `audio_service` `BaseAudioHandler` backed by a `just_audio`
/// [AudioPlayer]. Owns the queue (mirrored from `BaseAudioHandler.queue`)
/// and translates `just_audio.PlaybackEvent` / `PlayerState` into the
/// platform `PlaybackState` that drives the lock-screen / notification
/// controls.
///
/// One instance is built by `AudioService.init` at app start and held by
/// `audioHandlerProvider`. The handler outlives screen rebuilds.
class HeerrAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  HeerrAudioHandler({AudioPlayer? player})
      : _player = player ?? AudioPlayer(useLazyPreparation: false) {
    _wirePlayerStreams();
  }

  final AudioPlayer _player;

  // Guards [playSong] / [playAll] / [restoreQueue] against overlapping calls
  // to `_player.setAudioSources`. A double-tap on a Play button (or two
  // near-simultaneous taps on different Play buttons) previously fired two
  // concurrent `setAudioSources` calls on the same underlying ExoPlayer
  // instance — the first call's MediaCodec teardown raced the second's
  // codec allocation, leaking a MediaCodec whose async callback thread kept
  // posting to an already-dead Handler and eventually froze the UI thread
  // long enough to trip Android's ANR watchdog. Dropping the second call
  // outright (rather than queuing it) matches the disabled-button UX the
  // Download action already uses elsewhere.
  bool _isLoadingSource = false;

  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;
  AudioServiceShuffleMode _shuffleMode = AudioServiceShuffleMode.none;

  /// Expose the underlying player for tests / advanced callers (J2 uses it
  /// for the position stream). Most consumers should use the handler's
  /// `playbackState` and `mediaItem` streams instead.
  AudioPlayer get player => _player;

  // -------------------------------------------------------------------------
  // Player → PlaybackState bridge
  // -------------------------------------------------------------------------

  void _wirePlayerStreams() {
    _player.playbackEventStream.listen(_broadcastPlaybackState);
    _player.currentIndexStream.listen((int? index) {
      if (index != null && index < queue.value.length) {
        mediaItem.add(queue.value[index]);
      }
    });
  }

  void _broadcastPlaybackState(PlaybackEvent event) {
    final bool playing = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: <MediaControl>[
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const <MediaAction>{
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const <int>[0, 1, 3],
        processingState: _mapProcessingState(_player.processingState),
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex,
        repeatMode: _repeatMode,
        shuffleMode: _shuffleMode,
      ),
    );
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    return switch (state) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };
  }

  // -------------------------------------------------------------------------
  // Queue management
  // -------------------------------------------------------------------------

  /// Replace the current queue with [newQueue] and load it into the player.
  /// Does not start playback — callers choose via [play] / [playSong] /
  /// [playAll].
  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    queue.add(newQueue);
    await _player.setAudioSources(
      newQueue.map(_toAudioSource).toList(),
      initialIndex: 0,
      initialPosition: Duration.zero,
    );
    if (newQueue.isNotEmpty) {
      mediaItem.add(newQueue.first);
    }
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    final List<MediaItem> next = <MediaItem>[...queue.value, mediaItem];
    queue.add(next);
    await _player.addAudioSource(_toAudioSource(mediaItem));
  }

  /// #35: append [mediaItems] to the end of the current queue without
  /// interrupting playback. Batch counterpart of [addQueueItem] — one
  /// player call so ExoPlayer's gapless pre-preparation (R1) sees the
  /// whole batch at once.
  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    if (mediaItems.isEmpty) return;
    final List<MediaItem> next = <MediaItem>[...queue.value, ...mediaItems];
    queue.add(next);
    await _player.addAudioSources(mediaItems.map(_toAudioSource).toList());
  }

  /// #35: remove the queue entry at [index]. Out-of-range is a no-op.
  /// just_audio shifts its internal currentIndex when removing above the
  /// playing item, and skips to the next source when the playing item
  /// itself is removed — we re-derive [mediaItem] from the player's
  /// post-mutation index rather than second-guessing either case.
  @override
  Future<void> removeQueueItemAt(int index) async {
    final List<MediaItem> current = queue.value;
    if (index < 0 || index >= current.length) return;
    final List<MediaItem> next = <MediaItem>[...current]..removeAt(index);
    queue.add(next);
    await _player.removeAudioSourceAt(index);
    _rebroadcastCurrentItem(next);
  }

  /// #35: move the queue entry at [from] to position [to] (remove-then-
  /// insert semantics — matches both `ReorderableListView.onReorder` after
  /// the standard newIndex adjustment and just_audio's `moveAudioSource`).
  /// Out-of-range or no-op moves return without touching the player.
  Future<void> moveQueueItem(int from, int to) async {
    final List<MediaItem> current = queue.value;
    if (from == to) return;
    if (from < 0 || from >= current.length) return;
    if (to < 0 || to >= current.length) return;
    final List<MediaItem> next = <MediaItem>[...current];
    final MediaItem item = next.removeAt(from);
    next.insert(to, item);
    queue.add(next);
    await _player.moveAudioSource(from, to);
    _rebroadcastCurrentItem(next);
  }

  /// After a structural queue mutation the player's currentIndex can point
  /// at a different item while keeping the same numeric value (e.g. the
  /// playing item was removed), so `currentIndexStream` won't necessarily
  /// re-emit. Push the item at the player's index explicitly; null when
  /// the queue emptied.
  void _rebroadcastCurrentItem(List<MediaItem> next) {
    final int? cur = _player.currentIndex;
    if (cur != null && cur >= 0 && cur < next.length) {
      mediaItem.add(next[cur]);
    } else if (next.isEmpty) {
      mediaItem.add(null);
    }
  }

  AudioSource _toAudioSource(MediaItem item) {
    return AudioSource.uri(Uri.parse(item.id), tag: item);
  }

  // -------------------------------------------------------------------------
  // Helpers for the UI
  // -------------------------------------------------------------------------

  /// Replace the queue with a single song and start playback. A call that
  /// arrives while a previous [playSong] / [playAll] / [restoreQueue] is
  /// still loading its audio source is dropped — see [_isLoadingSource].
  Future<void> playSong(MediaItem item) async {
    if (_isLoadingSource) return;
    _isLoadingSource = true;
    try {
      await updateQueue(<MediaItem>[item]);
      await play();
    } finally {
      _isLoadingSource = false;
    }
  }

  /// Replace the queue with [items], optionally seek to a specific index,
  /// and start playback. Used by Library Album / Playlist "Play all". A
  /// call that arrives while a previous load is still in flight is dropped
  /// — see [_isLoadingSource].
  Future<void> playAll(List<MediaItem> items, {int startIndex = 0}) async {
    if (items.isEmpty) return;
    if (_isLoadingSource) return;
    _isLoadingSource = true;
    try {
      final int idx = startIndex.clamp(0, items.length - 1);
      queue.add(items);
      await _player.setAudioSources(
        items.map(_toAudioSource).toList(),
        initialIndex: idx,
        initialPosition: Duration.zero,
      );
      mediaItem.add(items[idx]);
      await play();
    } finally {
      _isLoadingSource = false;
    }
  }

  /// P1: restore a persisted queue from disk on cold start. Like [playAll]
  /// but **does not** call [play] — the user resumes manually via the
  /// mini-player or Now Playing screen. Seeks to [position] within the
  /// [currentIndex]-th track.
  ///
  /// [items] empty is a no-op (cold start with nothing previously queued).
  /// [currentIndex] is clamped to `items.length - 1`.
  Future<void> restoreQueue(
    List<MediaItem> items, {
    int currentIndex = 0,
    Duration position = Duration.zero,
  }) async {
    if (items.isEmpty) return;
    if (_isLoadingSource) return;
    _isLoadingSource = true;
    try {
      final int idx = currentIndex.clamp(0, items.length - 1);
      queue.add(items);
      await _player.setAudioSources(
        items.map(_toAudioSource).toList(),
        initialIndex: idx,
        initialPosition: position,
      );
      mediaItem.add(items[idx]);
    } finally {
      _isLoadingSource = false;
    }
  }

  // -------------------------------------------------------------------------
  // Transport (delegated to the player)
  // -------------------------------------------------------------------------

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else {
      // Most mobile music apps rewind on tap-prev at start of track.
      await _player.seek(Duration.zero);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    await _player.seek(Duration.zero, index: index);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeatMode = repeatMode;
    await _player.setLoopMode(_toLoopMode(repeatMode));
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _shuffleMode = shuffleMode;
    await _player.setShuffleModeEnabled(
        shuffleMode != AudioServiceShuffleMode.none);
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

  LoopMode _toLoopMode(AudioServiceRepeatMode mode) => switch (mode) {
        AudioServiceRepeatMode.none => LoopMode.off,
        AudioServiceRepeatMode.one => LoopMode.one,
        AudioServiceRepeatMode.group || AudioServiceRepeatMode.all => LoopMode.all,
      };

  /// PR2 (#53): playback-speed control for the podcast player. Not exposed
  /// on the music transport (`_Transport`) — only the podcast layout offers
  /// a speed picker. `_player.setSpeed` already causes `just_audio` to emit
  /// a `PlaybackEvent`, which `_broadcastPlaybackState` picks up via
  /// `speed: _player.speed` — but that emission isn't always synchronous
  /// with the call returning, so the state is rebroadcast explicitly here
  /// too, keeping `PlaybackState.speed` (and therefore
  /// `PlayerSnapshot.state.speed`) authoritative immediately after the call
  /// resolves, not just eventually.
  @override
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    playbackState.add(playbackState.value.copyWith(speed: _player.speed));
  }

  /// PR2 (#53): podcast transport skip-back/forward, a fixed 30s interval
  /// per the design (distinct from music's prev/next track skip). Clamped
  /// to `[Duration.zero, duration]` so it can't seek past either end.
  Future<void> skipBack30() => _seekByOffset(const Duration(seconds: -30));

  Future<void> skipForward30() => _seekByOffset(const Duration(seconds: 30));

  Future<void> _seekByOffset(Duration offset) async {
    final Duration current = _player.position;
    final Duration? duration = _player.duration;
    Duration target = current + offset;
    if (target < Duration.zero) target = Duration.zero;
    if (duration != null && target > duration) target = duration;
    await _player.seek(target);
  }

  /// Combined snapshot stream for the mini-player + Now Playing (J2).
  /// Emits a [PlayerSnapshot] whenever the current item or transport state
  /// changes.
  Stream<PlayerSnapshot> snapshotStream() {
    return Rx.combineLatest2<MediaItem?, PlaybackState, PlayerSnapshot>(
      mediaItem.stream,
      playbackState.stream,
      (MediaItem? m, PlaybackState s) => PlayerSnapshot(item: m, state: s),
    );
  }
}

/// Bundled view of "what's playing right now" — current item + transport.
class PlayerSnapshot {
  const PlayerSnapshot({required this.item, required this.state});
  final MediaItem? item;
  final PlaybackState state;

  bool get isPlaying => state.playing;
  Duration get position => state.position;
}
