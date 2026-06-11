import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'player/heerr_audio_handler.dart';
import 'player/player_provider.dart';
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

class HeerrApp extends StatelessWidget {
  const HeerrApp({super.key});

  @override
  Widget build(BuildContext context) {
    final GoRouter router = buildHeerrRouter();
    return MaterialApp.router(
      title: 'heerr',
      debugShowCheckedModeBanner: false,
      theme: heerrDarkTheme(),
      routerConfig: router,
    );
  }
}
