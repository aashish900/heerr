// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'jam_host.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$jamHostPollIntervalHash() =>
    r'4832f223263d4dd57760ab6599a175be29005f83';

/// Retry delay after a failed sync. Overridable for `fake_async` tests.
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
String _$jamHostHash() => r'ac55636cd727d7240ba5a440c7e8334818d4f55c';

/// Phase JM host side. While a session is live:
/// * a continuous `POST /jam/{id}/sync` long-poll ([kJamLongPollWaitS]) pulls
///   guest commands the moment they are sent and runs them strictly in
///   order, each awaited (the handler's `_isLoadingSource` guard drops
///   overlapping loads); retry after [jamHostPollInterval] on failure;
/// * every meaningful player change (track, play/pause, queue, seek) is
///   pushed via `PUT /jam/{id}/state` so guests see it at once.
/// `null` state = not hosting.
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
