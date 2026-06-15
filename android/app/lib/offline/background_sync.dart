import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workmanager/workmanager.dart';

import 'offline_manifest.dart';
import 'offline_settings.dart';
import 'offline_sync.dart';

part 'background_sync.g.dart';

/// Q1: WorkManager-driven background offline sync.
///
/// This file owns the *entry point* for the background isolate that
/// WorkManager spins up when its periodic constraint fires. It does NOT
/// schedule work — registration / cancellation lands at Q2 / Q3. Q1's job is
/// to prove the entry point delegates to the existing [OfflineSync.syncNow]
/// code path, so foreground and background ticks share a single
/// implementation (and a single set of manifest-write guarantees from L1).

/// Stable identifiers used by the Q2 scheduler. Defined here so test setup
/// and production scheduling can't drift.
const String kBackgroundSyncTaskName = 'heerr.offline_sync.tick';
const String kBackgroundSyncUniqueName = 'heerr.offline_sync.periodic';

/// WorkManager's hard minimum periodic interval. Setting anything lower
/// silently rounds up; we clamp explicitly so the value passed to
/// `registerPeriodicTask` matches what actually fires on the device.
const int kBackgroundSyncMinIntervalMinutes = 15;

/// Translate the user-facing offline settings into a workmanager
/// [Constraints] object. Pure function so Q2 unit-tests the 2×2
/// wifi/charging permutation without touching the plugin.
///
/// - `wifiOnly = true`  → require an **unmetered** network. WiFi-only is the
///   user's promise to never burn cellular; the unmetered constraint is the
///   closest WorkManager analog (a metered WiFi hotspot will still block,
///   which is the conservative call).
/// - `wifiOnly = false` → require any **connected** network. Skipping the
///   constraint entirely would let WorkManager fire on a flight-mode device.
/// - `chargingOnly = true` → require the device to be plugged in.
Constraints constraintsFor({
  required bool wifiOnly,
  required bool chargingOnly,
}) {
  return Constraints(
    networkType: wifiOnly ? NetworkType.unmetered : NetworkType.connected,
    requiresCharging: chargingOnly,
  );
}

/// Clamp the user-chosen poll interval to WorkManager's 15-minute floor.
/// The foreground sync timer in [OfflineSync] honours sub-15 values (down to
/// 5 minutes via the Settings dropdown); the background worker can't. A
/// shorter setting means "as eagerly as the OS allows" → 15 minutes.
int backgroundIntervalMinutesFor(int rawMinutes) {
  if (rawMinutes < kBackgroundSyncMinIntervalMinutes) {
    return kBackgroundSyncMinIntervalMinutes;
  }
  return rawMinutes;
}

/// Convenience wrapper that pulls both knobs straight from an
/// [OfflineSettingsValue]. Kept on the same surface as [constraintsFor] so
/// the call site (Q3 scheduler) only needs one import.
Constraints constraintsForSettings(OfflineSettingsValue settings) =>
    constraintsFor(
      wifiOnly: settings.wifiOnly,
      chargingOnly: settings.chargingOnly,
    );

/// Q3 scheduling surface. Wraps the two workmanager calls the lifecycle
/// handler needs so tests can swap in a recording stub. Production impl is
/// [_WorkmanagerScheduler]; the Riverpod binding lives in
/// [backgroundSyncScheduler].
abstract class BackgroundSyncScheduler {
  /// Register (or replace) the periodic worker.
  Future<void> schedule({
    required Constraints constraints,
    required Duration frequency,
  });

  /// Cancel the periodic worker. Idempotent — calling when nothing is
  /// scheduled is a no-op on the WorkManager side.
  Future<void> cancel();
}

class _WorkmanagerScheduler implements BackgroundSyncScheduler {
  @override
  Future<void> schedule({
    required Constraints constraints,
    required Duration frequency,
  }) {
    return Workmanager().registerPeriodicTask(
      kBackgroundSyncUniqueName,
      kBackgroundSyncTaskName,
      frequency: frequency,
      constraints: constraints,
      // `replace` is the right semantic for our schedule-on-background flow:
      // every backgrounding writes the current settings-derived constraints,
      // so the most recent enqueue is always authoritative.
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  @override
  Future<void> cancel() =>
      Workmanager().cancelByUniqueName(kBackgroundSyncUniqueName);
}

@Riverpod(keepAlive: true)
BackgroundSyncScheduler backgroundSyncScheduler(
  BackgroundSyncSchedulerRef ref,
) =>
    _WorkmanagerScheduler();

/// True when the manifest carries work the background tick would actually
/// pick up. Sync-all bypasses this check — the worker walks the full library
/// on its own. Otherwise: any marker (album / playlist / artist) counts.
///
/// Public so the lifecycle handler reads it directly and so it's easy to
/// unit-test the predicate in isolation.
bool hasPendingSyncTargets({
  required OfflineSettingsValue offline,
  required OfflineManifest manifest,
}) {
  if (offline.syncAll) return true;
  return manifest.markedAlbums.isNotEmpty ||
      manifest.markedPlaylists.isNotEmpty ||
      manifest.markedArtists.isNotEmpty;
}

/// Foreground-resume handler. Cancels any in-flight background work so the
/// foreground `OfflineSync` notifier is the sole writer to the manifest
/// while the app is visible — matches the cancel-on-resume rule from the
/// v2.0.0 ADR.
Future<void> onAppForegrounded(BackgroundSyncScheduler scheduler) async {
  await scheduler.cancel();
}

/// Background handler. Schedules the periodic worker iff offline is on and
/// the manifest holds work to do. Skipping the schedule when there's
/// nothing to download keeps idle devices out of WorkManager's queue.
Future<void> onAppBackgrounded({
  required BackgroundSyncScheduler scheduler,
  required OfflineSettingsValue offline,
  required OfflineManifest manifest,
}) async {
  if (!offline.enabled) return;
  if (!hasPendingSyncTargets(offline: offline, manifest: manifest)) return;
  await scheduler.schedule(
    constraints: constraintsForSettings(offline),
    frequency: Duration(
      minutes: backgroundIntervalMinutesFor(offline.pollIntervalMinutes),
    ),
  );
}

/// Top-level callback dispatcher invoked by the workmanager plugin in a
/// fresh background isolate. The `@pragma('vm:entry-point')` annotation
/// keeps it from being tree-shaken out of the release build.
@pragma('vm:entry-point')
void backgroundSyncCallbackDispatcher() {
  Workmanager().executeTask(
    (String taskName, Map<String, dynamic>? inputData) =>
        runBackgroundSyncTask(),
  );
}

/// One background tick. Builds a fresh [ProviderContainer], delegates to
/// [OfflineSync.syncNow] via the keep-alive `offlineSyncProvider`, then
/// disposes — releasing the dio client, secure-storage handle, and any
/// transient subscriptions.
///
/// [container] / [overrides] are an injection seam for tests. Production
/// callers leave them unset; the function bootstraps the Flutter binding
/// (required for `flutter_secure_storage` + `path_provider` method channels
/// in the background isolate) and builds a default container.
///
/// Returns `true` if the tick completed without throwing, `false` otherwise.
/// WorkManager treats `false` as "retry next interval" — which matches
/// `OfflineSync`'s own resilience contract (per-song failures are recorded
/// in the manifest, only an outright exception in `_runTick` reaches here).
Future<bool> runBackgroundSyncTask({
  ProviderContainer? container,
  List<Override> overrides = const <Override>[],
}) async {
  ProviderContainer? owned;
  final ProviderContainer c;
  if (container != null) {
    c = container;
  } else {
    // Background isolate: bind plugin method channels before any
    // `flutter_secure_storage` / `path_provider` call. No-op if already
    // initialized in the host isolate (e.g. when tests opt into the real
    // container path with a TestWidgetsFlutterBinding active).
    WidgetsFlutterBinding.ensureInitialized();
    owned = ProviderContainer(overrides: overrides);
    c = owned;
  }
  try {
    await c.read(offlineSyncProvider.notifier).syncNow();
    return true;
  } catch (_) {
    return false;
  } finally {
    owned?.dispose();
  }
}
