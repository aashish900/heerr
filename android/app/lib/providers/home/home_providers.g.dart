// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$homeNewestHash() => r'69a3cf9146eb5eb9e573f49c832648a5a1a23ff3';

/// Recently-added albums (`getAlbumList2.view?type=newest` — Subsonic
/// "newest" = most recently *added*, distinct from `recent` = recently
/// *played*). Home's only network-bound section post-redesign
/// (HOMESCREEN.md task 6); it doubles as the screen's canonical
/// network-health signal for the auto-retry loop.
///
/// Copied from [homeNewest].
@ProviderFor(homeNewest)
final homeNewestProvider = AutoDisposeFutureProvider<List<Album>>.internal(
  homeNewest,
  name: r'homeNewestProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$homeNewestHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef HomeNewestRef = AutoDisposeFutureProviderRef<List<Album>>;
String _$recentlyAddedFullHash() => r'1387272ee13674b8026012e40b3f8d7fb3ae9da1';

/// Full recently-added list for the "See all" screen. Separate provider
/// (not a rerun of [homeNewest]) so the Home section's 8-row fetch and the
/// screen's 50-row fetch cache independently.
///
/// Copied from [recentlyAddedFull].
@ProviderFor(recentlyAddedFull)
final recentlyAddedFullProvider =
    AutoDisposeFutureProvider<List<Album>>.internal(
      recentlyAddedFull,
      name: r'recentlyAddedFullProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$recentlyAddedFullHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RecentlyAddedFullRef = AutoDisposeFutureProviderRef<List<Album>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
