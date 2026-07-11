// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_filters.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$albumSortNotifierHash() => r'c68544ffddc0f72880da5a2a704eb6783826687d';

/// See also [AlbumSortNotifier].
@ProviderFor(AlbumSortNotifier)
final albumSortNotifierProvider =
    AutoDisposeNotifierProvider<AlbumSortNotifier, AlbumSort>.internal(
      AlbumSortNotifier.new,
      name: r'albumSortNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$albumSortNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AlbumSortNotifier = AutoDisposeNotifier<AlbumSort>;
String _$artistSortNotifierHash() =>
    r'ae3a2de922a001f2c28f9e44331933c26a8061d8';

/// See also [ArtistSortNotifier].
@ProviderFor(ArtistSortNotifier)
final artistSortNotifierProvider =
    AutoDisposeNotifierProvider<ArtistSortNotifier, ArtistSort>.internal(
      ArtistSortNotifier.new,
      name: r'artistSortNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$artistSortNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ArtistSortNotifier = AutoDisposeNotifier<ArtistSort>;
String _$playlistSortNotifierHash() =>
    r'50c57b7f05c3dca47a8b010e3b54f491eae50ef2';

/// See also [PlaylistSortNotifier].
@ProviderFor(PlaylistSortNotifier)
final playlistSortNotifierProvider =
    AutoDisposeNotifierProvider<PlaylistSortNotifier, PlaylistSort>.internal(
      PlaylistSortNotifier.new,
      name: r'playlistSortNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$playlistSortNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PlaylistSortNotifier = AutoDisposeNotifier<PlaylistSort>;
String _$downloadedOnlyNotifierHash() =>
    r'628da0dcb50cac860ed4c41e5fedc04544eec01f';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$DownloadedOnlyNotifier
    extends BuildlessAutoDisposeNotifier<bool> {
  late final LibraryTab tab;

  bool build(LibraryTab tab);
}

/// Per-tab "Downloaded" toggle — filters each tab down to items marked for
/// offline in the manifest (X3/X5/X6 wire the actual filtering).
///
/// Copied from [DownloadedOnlyNotifier].
@ProviderFor(DownloadedOnlyNotifier)
const downloadedOnlyNotifierProvider = DownloadedOnlyNotifierFamily();

/// Per-tab "Downloaded" toggle — filters each tab down to items marked for
/// offline in the manifest (X3/X5/X6 wire the actual filtering).
///
/// Copied from [DownloadedOnlyNotifier].
class DownloadedOnlyNotifierFamily extends Family<bool> {
  /// Per-tab "Downloaded" toggle — filters each tab down to items marked for
  /// offline in the manifest (X3/X5/X6 wire the actual filtering).
  ///
  /// Copied from [DownloadedOnlyNotifier].
  const DownloadedOnlyNotifierFamily();

  /// Per-tab "Downloaded" toggle — filters each tab down to items marked for
  /// offline in the manifest (X3/X5/X6 wire the actual filtering).
  ///
  /// Copied from [DownloadedOnlyNotifier].
  DownloadedOnlyNotifierProvider call(LibraryTab tab) {
    return DownloadedOnlyNotifierProvider(tab);
  }

  @override
  DownloadedOnlyNotifierProvider getProviderOverride(
    covariant DownloadedOnlyNotifierProvider provider,
  ) {
    return call(provider.tab);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'downloadedOnlyNotifierProvider';
}

/// Per-tab "Downloaded" toggle — filters each tab down to items marked for
/// offline in the manifest (X3/X5/X6 wire the actual filtering).
///
/// Copied from [DownloadedOnlyNotifier].
class DownloadedOnlyNotifierProvider
    extends AutoDisposeNotifierProviderImpl<DownloadedOnlyNotifier, bool> {
  /// Per-tab "Downloaded" toggle — filters each tab down to items marked for
  /// offline in the manifest (X3/X5/X6 wire the actual filtering).
  ///
  /// Copied from [DownloadedOnlyNotifier].
  DownloadedOnlyNotifierProvider(LibraryTab tab)
    : this._internal(
        () => DownloadedOnlyNotifier()..tab = tab,
        from: downloadedOnlyNotifierProvider,
        name: r'downloadedOnlyNotifierProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$downloadedOnlyNotifierHash,
        dependencies: DownloadedOnlyNotifierFamily._dependencies,
        allTransitiveDependencies:
            DownloadedOnlyNotifierFamily._allTransitiveDependencies,
        tab: tab,
      );

  DownloadedOnlyNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.tab,
  }) : super.internal();

  final LibraryTab tab;

  @override
  bool runNotifierBuild(covariant DownloadedOnlyNotifier notifier) {
    return notifier.build(tab);
  }

  @override
  Override overrideWith(DownloadedOnlyNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: DownloadedOnlyNotifierProvider._internal(
        () => create()..tab = tab,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        tab: tab,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<DownloadedOnlyNotifier, bool>
  createElement() {
    return _DownloadedOnlyNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is DownloadedOnlyNotifierProvider && other.tab == tab;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, tab.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin DownloadedOnlyNotifierRef on AutoDisposeNotifierProviderRef<bool> {
  /// The parameter `tab` of this provider.
  LibraryTab get tab;
}

class _DownloadedOnlyNotifierProviderElement
    extends AutoDisposeNotifierProviderElement<DownloadedOnlyNotifier, bool>
    with DownloadedOnlyNotifierRef {
  _DownloadedOnlyNotifierProviderElement(super.provider);

  @override
  LibraryTab get tab => (origin as DownloadedOnlyNotifierProvider).tab;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
