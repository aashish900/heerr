import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../player/heerr_audio_handler.dart';
import '../player/player_provider.dart';
import 'now_playing_widget.dart';

part 'now_playing_widget_provider.g.dart';

/// #20: keep-alive side-effect provider that mirrors the live player state
/// onto the home-screen widget. Watched by `HeerrApp` purely for the
/// subscription — same pattern as `nowPlayingPersistenceProvider`.
///
/// Listens to the fused [playerSnapshotProvider] and pushes each emission
/// through [NowPlayingWidgetUpdater]. Updates only happen while the app
/// process is alive; when the app is killed the widget keeps showing the
/// last-pushed state until the user reopens the app.
@Riverpod(keepAlive: true)
NowPlayingWidgetUpdater nowPlayingWidget(NowPlayingWidgetRef ref) {
  final NowPlayingWidgetUpdater updater = NowPlayingWidgetUpdater(
    client: const HomeWidgetClientImpl(),
    tintExtractor: const WidgetTintExtractorImpl(),
    artCache: WidgetArtCacheImpl(),
  );

  // Live 1 s progress ticker: while a track is playing, push the extrapolated
  // position every second so the hero/bar progress bar + m:ss timestamps
  // advance smoothly (the full `push` only fires on transport changes). Reads
  // `PlaybackState.position`, which audio_service extrapolates from its last
  // update time, so no per-tick handler call is needed beyond the read. Only
  // runs while the app process is alive; a killed app freezes the widget at the
  // last-pushed position (documented trade-off — no background isolate).
  Timer? ticker;
  void stopTicker() {
    ticker?.cancel();
    ticker = null;
  }

  void startTicker() {
    if (ticker != null) return;
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final Duration position =
          ref.read(audioHandlerProvider).playbackState.value.position;
      unawaited(updater.pushPosition(position));
    });
  }

  ref.listen<AsyncValue<PlayerSnapshot>>(
    playerSnapshotProvider,
    (AsyncValue<PlayerSnapshot>? _, AsyncValue<PlayerSnapshot> next) {
      final PlayerSnapshot? snapshot = next.valueOrNull;
      if (snapshot == null) return;
      unawaited(updater.push(snapshot));
      if (snapshot.isPlaying) {
        startTicker();
      } else {
        stopTicker();
      }
    },
    fireImmediately: true,
  );

  ref.onDispose(stopTicker);

  return updater;
}
