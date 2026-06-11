// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$audioHandlerHash() => r'7455955023fd24cad9b5d49e2543e8f87b7617e9';

/// Riverpod handle on the singleton [HeerrAudioHandler] created by
/// `AudioService.init` in `main()` and injected via
/// `audioHandlerProvider.overrideWithValue(handler)` on the root
/// ProviderScope.
///
/// Throws by default so tests and accidental reads before init blow up
/// loudly rather than silently spawning a rogue AudioPlayer.
///
/// Copied from [audioHandler].
@ProviderFor(audioHandler)
final audioHandlerProvider = Provider<HeerrAudioHandler>.internal(
  audioHandler,
  name: r'audioHandlerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$audioHandlerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AudioHandlerRef = ProviderRef<HeerrAudioHandler>;
String _$playerSnapshotHash() => r'0ce86cf42a6814f015c59a4fe006cc429f0a8dad';

/// Stream of "what is playing right now" — current MediaItem + PlaybackState.
/// J2 mini-player and Now Playing screens drive off this.
///
/// Copied from [playerSnapshot].
@ProviderFor(playerSnapshot)
final playerSnapshotProvider = StreamProvider<PlayerSnapshot>.internal(
  playerSnapshot,
  name: r'playerSnapshotProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$playerSnapshotHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PlayerSnapshotRef = StreamProviderRef<PlayerSnapshot>;
String _$currentMediaItemHash() => r'85f41226ab32ab0cc235d4d6356878fcd9e9dfb8';

/// Convenience: just the current MediaItem (null when nothing queued).
///
/// Copied from [currentMediaItem].
@ProviderFor(currentMediaItem)
final currentMediaItemProvider = AutoDisposeStreamProvider<MediaItem?>.internal(
  currentMediaItem,
  name: r'currentMediaItemProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentMediaItemHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentMediaItemRef = AutoDisposeStreamProviderRef<MediaItem?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
