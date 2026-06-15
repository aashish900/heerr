import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'player/heerr_audio_handler.dart';
import 'player/now_playing_persistence.dart';
import 'player/player_provider.dart';
import 'player/scrobble_provider.dart';
import 'router.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final HeerrAudioHandler handler = await AudioService.init(
    builder: HeerrAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.aashish.heerr.audio',
      androidNotificationChannelName: 'heerr playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  runApp(
    ProviderScope(
      overrides: <Override>[
        audioHandlerProvider.overrideWithValue(handler),
      ],
      child: const HeerrApp(),
    ),
  );
}

class HeerrApp extends ConsumerWidget {
  const HeerrApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Boot the scrobble controller. Keep-alive provider; the result is
    // discarded — we only need the side effect (stream subscription).
    ref.watch(scrobbleProvider);

    // P1: wire the Now Playing persistence orchestrator (subscribes to
    // handler streams, debounced 500ms save) and fire the one-shot
    // cold-start restore. Both are keep-alive — `watch` here is purely
    // for the side effect.
    ref.watch(nowPlayingPersistenceProvider);
    ref.watch(nowPlayingRestoreProvider);

    final GoRouter router = buildHeerrRouter();
    return MaterialApp.router(
      title: 'heerr',
      debugShowCheckedModeBanner: false,
      theme: heerrDarkTheme(),
      routerConfig: router,
    );
  }
}
