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
  );

  ref.listen<AsyncValue<PlayerSnapshot>>(
    playerSnapshotProvider,
    (AsyncValue<PlayerSnapshot>? _, AsyncValue<PlayerSnapshot> next) {
      final PlayerSnapshot? snapshot = next.valueOrNull;
      if (snapshot != null) {
        unawaited(updater.push(snapshot));
      }
    },
    fireImmediately: true,
  );

  return updater;
}
