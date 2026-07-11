// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'starred_songs.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$starredSongsHash() => r'39128f68e55b73d68dd651108ba714d860d8ac58';

/// The user's starred ("loved") songs via `getStarred2.view`. Powers the
/// Favorites screen reached from Home's Quick Access row (HOMESCREEN.md
/// task 5).
///
/// Copied from [starredSongs].
@ProviderFor(starredSongs)
final starredSongsProvider = AutoDisposeFutureProvider<List<Song>>.internal(
  starredSongs,
  name: r'starredSongsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$starredSongsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef StarredSongsRef = AutoDisposeFutureProviderRef<List<Song>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
