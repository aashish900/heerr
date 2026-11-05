// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'jam_display.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$displaySnapshotHash() => r'f721787fe6a563d0a09c14ddb5e4ace1e9b274cb';

/// JM: what Now Playing + the mini-player show. Normally the local player;
/// while this phone controls a jam host, the host's polled snapshot rebuilt
/// as a [PlayerSnapshot] so the same screens render it. A plain provider
/// (not a stream) so a 2s poll swaps the value without a loading flash.
///
/// Copied from [displaySnapshot].
@ProviderFor(displaySnapshot)
final displaySnapshotProvider =
    AutoDisposeProvider<AsyncValue<PlayerSnapshot>>.internal(
      displaySnapshot,
      name: r'displaySnapshotProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$displaySnapshotHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DisplaySnapshotRef = AutoDisposeProviderRef<AsyncValue<PlayerSnapshot>>;
String _$displayQueueHash() => r'efeae21f09026545bc30735df711a48627528cea';

/// JM: the queue Now Playing's sheet lists (host's while joined, from its
/// current index onward).
///
/// Copied from [displayQueue].
@ProviderFor(displayQueue)
final displayQueueProvider =
    AutoDisposeProvider<AsyncValue<List<MediaItem>>>.internal(
      displayQueue,
      name: r'displayQueueProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$displayQueueHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DisplayQueueRef = AutoDisposeProviderRef<AsyncValue<List<MediaItem>>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
