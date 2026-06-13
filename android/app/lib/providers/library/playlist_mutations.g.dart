// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlist_mutations.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$playlistMutationsHash() => r'f98b4a63b28f719e8497eb2657a264af6a9e9415';

/// Subsonic playlist-mutation notifier. Stateless: `build()` returns void
/// and the six methods drive `createPlaylist` / `updatePlaylist` /
/// `deletePlaylist` through [subsonicCall], invalidating the affected
/// read providers ([libraryPlaylistsProvider], [libraryPlaylistProvider])
/// on success so the cache-aware wrappers refetch fresh data on the next
/// read.
///
/// Wire contract: every method goes through [subsonicDioClientProvider],
/// so auth (`u/s/t/v/c/f`) is injected by `SubsonicAuthInterceptor`. The
/// envelope shape is the standard `{"subsonic-response": {...}}`; failures
/// are surfaced as the matching [ApiError] subclass (so callers compose
/// with `reactToApiError` / `showApiError`).
///
/// `keepAlive: true` because this notifier holds no mutable state and is
/// referenced from short-lived UI surfaces (dialogs, snackbars). Letting
/// it auto-dispose between calls would re-build the type for every tap.
///
/// Copied from [PlaylistMutations].
@ProviderFor(PlaylistMutations)
final playlistMutationsProvider =
    NotifierProvider<PlaylistMutations, void>.internal(
      PlaylistMutations.new,
      name: r'playlistMutationsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$playlistMutationsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PlaylistMutations = Notifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
