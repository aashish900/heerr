// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_views.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sortedLibraryAlbumsHash() =>
    r'f09ad1fa0114daf8f1fc34b0ab0507228487ca25';

/// The Albums tab's view of the library (X3, LIBRARYSCREEN.md §4):
/// `libraryAlbumsProvider`'s full fetch, re-sorted per the sort chip and
/// optionally filtered to offline-marked albums. Pure derivation — no
/// network beyond the underlying cached fetch. The manifest is only awaited
/// when the Downloaded filter is on, so browsing stays independent of
/// offline-subsystem readiness.
///
/// Copied from [sortedLibraryAlbums].
@ProviderFor(sortedLibraryAlbums)
final sortedLibraryAlbumsProvider =
    AutoDisposeFutureProvider<List<Album>>.internal(
      sortedLibraryAlbums,
      name: r'sortedLibraryAlbumsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$sortedLibraryAlbumsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SortedLibraryAlbumsRef = AutoDisposeFutureProviderRef<List<Album>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
