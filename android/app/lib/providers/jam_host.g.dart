// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'jam_host.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$jamHostPollIntervalHash() =>
    r'4832f223263d4dd57760ab6599a175be29005f83';

/// Host sync cadence. Overridable for `fake_async` tests.
///
/// Copied from [jamHostPollInterval].
@ProviderFor(jamHostPollInterval)
final jamHostPollIntervalProvider = Provider<Duration>.internal(
  jamHostPollInterval,
  name: r'jamHostPollIntervalProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$jamHostPollIntervalHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef JamHostPollIntervalRef = ProviderRef<Duration>;
String _$jamHostHash() => r'28e89314752d2a77336f2fc627352d2189a94600';

/// Phase JM host side: while a session is live, every [jamHostPollInterval]
/// push the player snapshot and pull guest commands via `POST /jam/{id}/sync`,
/// then run them strictly in order, each awaited (the handler's
/// `_isLoadingSource` guard drops overlapping loads). One-shot `Timer`
/// rescheduled after each tick (same shape as `queue.dart`), so ticks never
/// overlap. `null` state = not hosting.
///
/// Copied from [JamHost].
@ProviderFor(JamHost)
final jamHostProvider = NotifierProvider<JamHost, JamHostStatus?>.internal(
  JamHost.new,
  name: r'jamHostProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$jamHostHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$JamHost = Notifier<JamHostStatus?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
