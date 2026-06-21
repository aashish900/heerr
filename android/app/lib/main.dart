import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:workmanager/workmanager.dart';

import 'offline/background_sync.dart';
import 'player/heerr_audio_handler.dart';
import 'player/now_playing_persistence.dart';
import 'player/player_provider.dart';
import 'player/scrobble_provider.dart';
import 'providers/prefs_storage.dart';
import 'providers/profiles/legacy_migration.dart';
import 'router.dart';
import 'theme.dart';
import 'widget/now_playing_widget_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Q1: initialize WorkManager so the Q2 scheduler has a callback to dispatch
  // periodic offline-sync ticks to. Registration of the actual periodic task
  // lands at Q2 — this call only wires the dispatcher.
  await Workmanager().initialize(backgroundSyncCallbackDispatcher);
  final HeerrAudioHandler handler = await AudioService.init(
    builder: HeerrAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.aashish.heerr.audio',
      androidNotificationChannelName: 'heerr playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'drawable/ic_stat_heerr',
    ),
  );

  // S3: one-shot migration of legacy single-set credentials into a Phase-S
  // Profile. No-op on fresh installs and on already-migrated installs.
  // Runs against a parent ProviderContainer that ProviderScope adopts so
  // any work done here is observable to the rest of the app.
  final ProviderContainer rootContainer = ProviderContainer(
    overrides: <Override>[
      audioHandlerProvider.overrideWithValue(handler),
    ],
  );
  await migrateLegacyCreds(rootContainer);
  // A5: relocate offline-download prefs out of EncryptedSharedPreferences
  // into plain shared_preferences. Idempotent — no-op once the keys are
  // gone from secure storage.
  await migrateOfflinePrefs(rootContainer);

  runApp(
    UncontrolledProviderScope(
      container: rootContainer,
      child: HeerrApp(rootContainer: rootContainer),
    ),
  );
}

// HeerrApp must be a StatefulWidget so the GoRouter is created once in
// initState and held as a field. Creating it inside ConsumerWidget.build()
// was the root cause of the "save settings → navigation reset to Home" bug:
// when settingsProvider changed (e.g. on first server save), scrobbleProvider
// rebuilt, which triggered build() again, which created a brand-new GoRouter
// with initialLocation '/' — resetting the navigation stack.
class HeerrApp extends ConsumerStatefulWidget {
  const HeerrApp({super.key, required this.rootContainer});

  /// The same [ProviderContainer] passed to [UncontrolledProviderScope].
  /// Injected explicitly because reading the inherited widget during
  /// `initState` via `ProviderScope.containerOf(context)` violates
  /// Flutter's `dependOnInheritedWidgetOfExactType-before-initState`
  /// rule and crashes the first launch.
  final ProviderContainer rootContainer;

  @override
  ConsumerState<HeerrApp> createState() => _HeerrAppState();
}

class _HeerrAppState extends ConsumerState<HeerrApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildHeerrRouter(container: widget.rootContainer);
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Boot the scrobble controller. Keep-alive provider; the result is
    // discarded — we only need the side effect (stream subscription).
    ref.watch(scrobbleProvider);

    // P1: wire the Now Playing persistence orchestrator + cold-start
    // restore. Both are keep-alive — `watch` here is purely for the
    // side effect. Rebuilds of this widget triggered by these providers
    // are now safe because the router is held in state, not recreated.
    ref.watch(nowPlayingPersistenceProvider);
    ref.watch(nowPlayingRestoreProvider);

    // #20: mirror live playback onto the home-screen widget. Keep-alive
    // side-effect provider — watched only for the subscription.
    ref.watch(nowPlayingWidgetProvider);

    return MaterialApp.router(
      title: 'heerr',
      debugShowCheckedModeBanner: false,
      theme: heerrDarkTheme(),
      routerConfig: _router,
    );
  }
}
