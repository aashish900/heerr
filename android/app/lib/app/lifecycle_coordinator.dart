import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../offline/background_sync.dart';
import '../offline/offline_manifest.dart';
import '../offline/offline_settings.dart';
import '../offline/offline_sync.dart';
import '../player/now_playing_persistence.dart';
import '../providers/recommendations.dart';

/// Hosts every app-lifecycle side-effect for the foregrounded shell (A8).
///
/// Extracted from the former `_ShellScaffold` god-class in `router.dart` so the
/// nav chrome stays a pure layout widget and the lifecycle concern is testable
/// in isolation. Composed by the ShellRoute builder around the shell scaffold;
/// it is always mounted while the app is foregrounded (Settings is a child
/// route, not a peer), which makes it the correct host for forwarding
/// [AppLifecycleState] transitions into the offline-sync notifier.
///
/// Responsibilities (verbatim from the old shell state):
///  - kick `offlineSyncProvider` so it builds + auto-syncs on launch
///  - pause()/resume() the sync notifier on background/foreground
///  - flush the Now-Playing snapshot on background (P1)
///  - schedule / cancel the background-sync worker (Q3)
///  - re-check recommendation-engine health on resume (N5)
class LifecycleCoordinator extends ConsumerStatefulWidget {
  const LifecycleCoordinator({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LifecycleCoordinator> createState() =>
      _LifecycleCoordinatorState();
}

class _LifecycleCoordinatorState extends ConsumerState<LifecycleCoordinator>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Kick the offline sync provider so it builds + auto-syncs on app
    // launch. We don't watch it (would rebuild on every status change) —
    // just trigger the build.
    Future<void>.microtask(() {
      if (!mounted) return;
      // ignore: unused_local_variable
      final dynamic _ = ref.read(offlineSyncProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Forward foreground/background transitions to the sync provider's
    // Timer. Matches the QueueScreen lifecycle pattern.
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        ref.read(offlineSyncProvider.notifier).pause();
        // P1: flush the Now Playing snapshot so position survives an
        // OS-may-kill-us next. Best-effort — async-fire-and-forget.
        unawaited(_flushNowPlaying());
        // Q3: hand off to the background worker. Skips when offline is off
        // or the manifest has no markers — the predicate lives inside
        // `onAppBackgrounded` so the lifecycle hook stays declarative.
        unawaited(_scheduleBackgroundSync());
      case AppLifecycleState.resumed:
        // Q3: cancel any in-flight background work so the foreground
        // notifier is the sole manifest writer while the app is visible —
        // no double-downloads. Fire-and-forget; resume() runs synchronously
        // below regardless of how the cancel completes.
        unawaited(_cancelBackgroundSync());
        unawaitedResume();
      case AppLifecycleState.detached:
        // App is fully detaching; the provider's onDispose will cancel the
        // timer when the container tears down.
        break;
    }
  }

  Future<void> _flushNowPlaying() async {
    try {
      final NowPlayingPersistence p =
          await ref.read(nowPlayingPersistenceProvider.future);
      await p.flush();
    } catch (_) {
      // Best-effort; swallow.
    }
  }

  void unawaitedResume() {
    // Fire-and-forget — resume() ticks immediately, but we don't need to
    // await it; failures land in the manifest's lastError.
    ref.read(offlineSyncProvider.notifier).resume();
    // N5: also re-check the recommendation engine's health on resume. The
    // notifier guards on a 60 s TTL so this is cheap to fire on every
    // foreground transition.
    ref.read(recommendHealthNotifierProvider.notifier).refreshIfStale();
  }

  Future<void> _cancelBackgroundSync() async {
    try {
      await onAppForegrounded(ref.read(backgroundSyncSchedulerProvider));
    } catch (_) {
      // Best-effort — the manifest is the source of truth either way.
    }
  }

  Future<void> _scheduleBackgroundSync() async {
    try {
      final OfflineSettingsValue? offline =
          ref.read(offlineSettingsProvider).valueOrNull;
      final OfflineManifest? manifest =
          ref.read(offlineManifestProvider).valueOrNull;
      if (offline == null || manifest == null) return;
      await onAppBackgrounded(
        scheduler: ref.read(backgroundSyncSchedulerProvider),
        offline: offline,
        manifest: manifest,
      );
    } catch (_) {
      // Best-effort — the next backgrounding gets another shot.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
