// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'now_playing_persistence.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$nowPlayingPersistenceHash() =>
    r'5a18914f48d186c14d140595dc02e0545a2b5ee1';

/// Keep-alive provider for the runtime persistence orchestrator. Watched
/// by the root app widget for its side effect — `start(...)` wires the
/// save listeners on first access.
///
/// Copied from [nowPlayingPersistence].
@ProviderFor(nowPlayingPersistence)
final nowPlayingPersistenceProvider =
    FutureProvider<NowPlayingPersistence>.internal(
      nowPlayingPersistence,
      name: r'nowPlayingPersistenceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$nowPlayingPersistenceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NowPlayingPersistenceRef = FutureProviderRef<NowPlayingPersistence>;
String _$nowPlayingRestoreHash() => r'83688ee3bdede823e12357c806dbf30be26aee97';

/// Cold-start queue restore. Runs once at app boot via a keep-alive
/// provider watched by [HeerrApp] for its side effect.
///
/// Flow:
///   1. Load the snapshot from disk. Null / empty / corrupt → no-op.
///   2. Resolve Navidrome creds + the offline manifest. Missing creds →
///      no-op (the songs would have no playable URI anyway; user goes
///      to Settings first).
///   3. For each [Song] in the snapshot, resolve a `localFilePath` via
///      the offline layer (chokepoint at `localUriForProvider`) — same
///      path `playback_actions.dart` uses to prefer-local over stream.
///   4. Build [MediaItem]s via [songToMediaItem] with **current** creds.
///      Auth salts rotate per process — never restore the old URLs.
///   5. Call [HeerrAudioHandler.restoreQueue] which sets the queue +
///      seeks but does **not** call `play()`. User taps to resume.
///
/// Failures throughout are caught and ignored — restore is best-effort,
/// not a play-blocking gate.
///
/// Copied from [nowPlayingRestore].
@ProviderFor(nowPlayingRestore)
final nowPlayingRestoreProvider = FutureProvider<void>.internal(
  nowPlayingRestore,
  name: r'nowPlayingRestoreProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$nowPlayingRestoreHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NowPlayingRestoreRef = FutureProviderRef<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
