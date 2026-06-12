// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_marker.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$offlineMarkerHash() => r'36bd409bb08d21fd9734b825cb2c1560d33520bd';

/// Mark / unmark albums + playlists for offline sync.
///
/// Mutations write through [OfflineManifestStore] and invalidate
/// [offlineManifestProvider] so the next reader sees the change. The size
/// estimate cache (L4 — `estimatedTotalBytes` / `estimatedAt`) is cleared on
/// every marker change so the Settings screen doesn't show a stale "≈ 1.2
/// GB" after the user adds another album.
///
/// `OfflineSync` (L2.4) is invalidated indirectly via the manifest watch;
/// `OfflineSync.syncNow()` is the manual trigger if the user wants a sync
/// immediately after marking.
///
/// Copied from [OfflineMarker].
@ProviderFor(OfflineMarker)
final offlineMarkerProvider =
    AsyncNotifierProvider<OfflineMarker, void>.internal(
      OfflineMarker.new,
      name: r'offlineMarkerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$offlineMarkerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$OfflineMarker = AsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
