// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_sync.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$wifiCheckHash() => r'cb18d75e6cbae8515b3c310fc0fbd2dc35d8957e';

/// See also [wifiCheck].
@ProviderFor(wifiCheck)
final wifiCheckProvider = Provider<WifiCheck>.internal(
  wifiCheck,
  name: r'wifiCheckProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$wifiCheckHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WifiCheckRef = ProviderRef<WifiCheck>;
String _$offlineSyncHash() => r'e02a6d42a6ad5af461e03aff20880097e10c9c19';

/// Reconciles the on-disk song set against the markers (or — at L4 — the
/// full library when sync-all is on). Owns its own Timer; pause()/resume()
/// is driven from `_ShellScaffold` (L3).
///
/// Copied from [OfflineSync].
@ProviderFor(OfflineSync)
final offlineSyncProvider =
    AsyncNotifierProvider<OfflineSync, OfflineSyncStatus>.internal(
      OfflineSync.new,
      name: r'offlineSyncProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$offlineSyncHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$OfflineSync = AsyncNotifier<OfflineSyncStatus>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
