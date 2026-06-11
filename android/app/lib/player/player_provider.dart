import 'package:audio_service/audio_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'heerr_audio_handler.dart';

part 'player_provider.g.dart';

/// Riverpod handle on the singleton [HeerrAudioHandler] created by
/// `AudioService.init` at app start. This provider has no default value —
/// `main()` must override it before mounting the widget tree, and tests
/// must override it with a stub before pumping any widget that consumes it.
///
/// Throwing here (rather than constructing a default handler) ensures we
/// never accidentally spawn a `just_audio.AudioPlayer` in a test or before
/// `AudioService.init` has run.
@Riverpod(keepAlive: true)
HeerrAudioHandler audioHandler(AudioHandlerRef ref) {
  throw UnimplementedError(
    'audioHandlerProvider was not overridden. main() must initialize it via '
    'AudioService.init and override the provider before mounting the app.',
  );
}

/// Stream of "what's playing right now" — current item + playback state.
/// Backed by [HeerrAudioHandler.snapshotStream]. UI widgets watch this to
/// render mini-player + Now Playing at J2.
@Riverpod(keepAlive: true)
Stream<PlayerSnapshot> playerSnapshot(PlayerSnapshotRef ref) {
  final HeerrAudioHandler handler = ref.watch(audioHandlerProvider);
  return handler.snapshotStream();
}

/// Convenience: just the current MediaItem (or null when nothing's playing).
@riverpod
Stream<MediaItem?> currentMediaItem(CurrentMediaItemRef ref) {
  final HeerrAudioHandler handler = ref.watch(audioHandlerProvider);
  return handler.mediaItem.stream;
}
