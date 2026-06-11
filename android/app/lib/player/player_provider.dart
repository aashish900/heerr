import 'package:audio_service/audio_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'heerr_audio_handler.dart';

part 'player_provider.g.dart';

/// Riverpod handle on the singleton [HeerrAudioHandler] created by
/// `AudioService.init` in `main()` and injected via
/// `audioHandlerProvider.overrideWithValue(handler)` on the root
/// ProviderScope.
///
/// Throws by default so tests and accidental reads before init blow up
/// loudly rather than silently spawning a rogue AudioPlayer.
@Riverpod(keepAlive: true)
HeerrAudioHandler audioHandler(AudioHandlerRef ref) {
  throw UnimplementedError(
    'audioHandlerProvider was not overridden. '
    'main() must call AudioService.init and override this provider.',
  );
}

/// Stream of "what is playing right now" — current MediaItem + PlaybackState.
/// J2 mini-player and Now Playing screens drive off this.
@Riverpod(keepAlive: true)
Stream<PlayerSnapshot> playerSnapshot(PlayerSnapshotRef ref) {
  return ref.watch(audioHandlerProvider).snapshotStream();
}

/// Convenience: just the current MediaItem (null when nothing queued).
@riverpod
Stream<MediaItem?> currentMediaItem(CurrentMediaItemRef ref) {
  return ref.watch(audioHandlerProvider).mediaItem.stream;
}
