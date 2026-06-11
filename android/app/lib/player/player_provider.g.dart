// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$audioHandlerHash() => r'399d0f117871fe07aa20b8a151218ddf22ba1a5f';

/// Riverpod handle on the singleton [HeerrAudioHandler] created by
/// `AudioService.init` at app start. This provider has no default value —
/// `main()` must override it before mounting the widget tree, and tests
/// must override it with a stub before pumping any widget that consumes it.
///
/// Throwing here (rather than constructing a default handler) ensures we
/// never accidentally spawn a `just_audio.AudioPlayer` in a test or before
/// `AudioService.init` has run.
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
String _$playerSnapshotHash() => r'43590e8e4face2645b14929cd8f792011cdff00f';

/// Stream of "what's playing right now" — current item + playback state.
/// Backed by [HeerrAudioHandler.snapshotStream]. UI widgets watch this to
/// render mini-player + Now Playing at J2.
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
String _$currentMediaItemHash() => r'6a85681af60e56e2ca23389c386c4f4d2e2da632';

/// Convenience: just the current MediaItem (or null when nothing's playing).
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
