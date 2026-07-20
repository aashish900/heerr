// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'episode_progress_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$episodeProgressHash() => r'f814af254cf8ae5b61987c0263b6c8604a2d236f';

/// Boots an [EpisodeProgressController] wired to the running
/// `HeerrAudioHandler` + [BackendService]. Keep-alive so it survives screen
/// rebuilds and tracks every episode play across the session — same shape
/// as `scrobble_provider.dart::scrobbleProvider`.
///
/// Read once at the root of the widget tree (see `HeerrApp.build`) to
/// trigger the subscription chain. Exposes nothing the UI needs — its work
/// is purely the side-effecting controller it owns.
///
/// Copied from [episodeProgress].
@ProviderFor(episodeProgress)
final episodeProgressProvider = FutureProvider<void>.internal(
  episodeProgress,
  name: r'episodeProgressProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$episodeProgressHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef EpisodeProgressRef = FutureProviderRef<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
