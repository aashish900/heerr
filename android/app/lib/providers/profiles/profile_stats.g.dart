// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_stats.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$profileStatsHash() => r'1459443ff471d74219bbb30865185cb5de8fee40';

/// Sums the three library list providers into [ProfileStats]. `songs` sums
/// each [Album.songCount] (null-safe — Subsonic always populates it on
/// `getAlbumList2`, but a stray null contributes zero rather than throwing).
///
/// Undercounts past 500 albums: [libraryAlbumsProvider] pages at 500 (same
/// cap as the Albums sub-tab) — acceptable for a stats display.
///
/// Copied from [profileStats].
@ProviderFor(profileStats)
final profileStatsProvider = AutoDisposeFutureProvider<ProfileStats>.internal(
  profileStats,
  name: r'profileStatsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$profileStatsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ProfileStatsRef = AutoDisposeFutureProviderRef<ProfileStats>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
