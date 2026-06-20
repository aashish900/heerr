// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlist_mutations.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$playlistMutationsHash() => r'cd94ea4661b027db6abd199159b220a7b76e81c4';

/// Subsonic playlist-mutation notifier. Stateless: `build()` returns void
/// and the methods drive create / update / delete through [PlaylistService],
/// invalidating the affected read providers ([libraryPlaylistsProvider],
/// [libraryPlaylistProvider]) on success so the cache-aware wrappers refetch
/// fresh data on the next read.
///
/// A10: the transport moved to [PlaylistService]; this notifier keeps the
/// rules that need a `Ref` — dedupe, index ordering, provider invalidation,
/// and the [toggleFavourite] orchestration.
///
/// `keepAlive: true` because this notifier holds no mutable state and is
/// referenced from short-lived UI surfaces (dialogs, snackbars).
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
