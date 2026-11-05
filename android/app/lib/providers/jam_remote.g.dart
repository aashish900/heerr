// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'jam_remote.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$jamRemotePollIntervalHash() =>
    r'8618e6ca8e25e42fd59ffc66ae1cd7d87d025738';

/// Retry delay after a failed state poll. Overridable for `fake_async` tests.
///
/// Copied from [jamRemotePollInterval].
@ProviderFor(jamRemotePollInterval)
final jamRemotePollIntervalProvider = Provider<Duration>.internal(
  jamRemotePollInterval,
  name: r'jamRemotePollIntervalProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$jamRemotePollIntervalHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef JamRemotePollIntervalRef = ProviderRef<Duration>;
String _$jamRemoteHash() => r'798dd472d3cb058a392625d37cf8c74292d46b00';

/// Phase JM guest side. While joined, the play / queue wrappers in
/// `player/playback_actions.dart` send commands here instead of touching the
/// local player, and the host's snapshot is long-polled (`since` the last
/// `state_at`), so a host change shows within ~one network round trip.
/// Play / pause / seek also patch the shown snapshot at once (optimistic).
/// Paused while the app is backgrounded. A host that stops the session
/// flips `ended`, which leaves automatically.
/// `null` state = not joined.
///
/// Copied from [JamRemote].
@ProviderFor(JamRemote)
final jamRemoteProvider =
    NotifierProvider<JamRemote, JamRemoteStatus?>.internal(
      JamRemote.new,
      name: r'jamRemoteProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$jamRemoteHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$JamRemote = Notifier<JamRemoteStatus?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
