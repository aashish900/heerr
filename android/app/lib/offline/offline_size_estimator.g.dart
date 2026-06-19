// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_size_estimator.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$offlineSizeEstimateHash() =>
    r'ebb18bf31ed655d30a180e37ad72da336f32ac73';

/// Walks the full library and sums `song.size` across every album. Returns
/// `null` when there are no Navidrome creds (the Settings UI shows
/// "Calculating…" while loading and "—" on null). Caches the result on the
/// manifest (`estimatedTotalBytes` + `estimatedAt`); subsequent watches
/// within [_kEstimateTtl] short-circuit on the cache.
///
/// The cache is cleared by `OfflineMarker` mutators and by
/// `OfflineSettings.setSyncAll` per the L4 spec — even though the estimate
/// value itself is independent of markers / syncAll, the spec is what the
/// roadmap froze and the cost of an extra recompute is bounded.
///
/// Copied from [OfflineSizeEstimate].
@ProviderFor(OfflineSizeEstimate)
final offlineSizeEstimateProvider =
    AsyncNotifierProvider<OfflineSizeEstimate, int?>.internal(
      OfflineSizeEstimate.new,
      name: r'offlineSizeEstimateProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$offlineSizeEstimateHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$OfflineSizeEstimate = AsyncNotifier<int?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
