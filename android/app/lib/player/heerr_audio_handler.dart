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
      : _player = player ?? AudioPlayer() {
    _wirePlayerStreams();
  }

  final AudioPlayer _player;

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
    await _player.setAudioSources(
      next.map(_toAudioSource).toList(),
      initialIndex: _player.currentIndex ?? 0,
      initialPosition: _player.position,
    );
  }

  AudioSource _toAudioSource(MediaItem item) {
    return AudioSource.uri(Uri.parse(item.id), tag: item);
  }

  // -------------------------------------------------------------------------
  // Helpers for the UI
  // -------------------------------------------------------------------------

  /// Replace the queue with a single song and start playback.
  Future<void> playSong(MediaItem item) async {
    await updateQueue(<MediaItem>[item]);
    await play();
  }

  /// Replace the queue with [items], optionally seek to a specific index,
  /// and start playback. Used by Library Album / Playlist "Play all".
  Future<void> playAll(List<MediaItem> items, {int startIndex = 0}) async {
    if (items.isEmpty) return;
    final int idx = startIndex.clamp(0, items.length - 1);
    queue.add(items);
    await _player.setAudioSources(
      items.map(_toAudioSource).toList(),
      initialIndex: idx,
      initialPosition: Duration.zero,
    );
    mediaItem.add(items[idx]);
    await play();
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
