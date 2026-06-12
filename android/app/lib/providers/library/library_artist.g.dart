// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_artist.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$libraryArtistHash() => r'eb34fd5f3f063ac796f3693622afb36866d22dd0';

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

/// Wraps `GET /rest/getArtist.view?id=<id>`. Returns one [Artist] with its
/// `album` list populated. Family-keyed by artist id so the album-detail
/// route can subscribe directly.
///
/// L5: cache-aware. See [libraryAlbum] for the contract.
///
/// Copied from [libraryArtist].
@ProviderFor(libraryArtist)
const libraryArtistProvider = LibraryArtistFamily();

/// Wraps `GET /rest/getArtist.view?id=<id>`. Returns one [Artist] with its
/// `album` list populated. Family-keyed by artist id so the album-detail
/// route can subscribe directly.
///
/// L5: cache-aware. See [libraryAlbum] for the contract.
///
/// Copied from [libraryArtist].
class LibraryArtistFamily extends Family<AsyncValue<Artist>> {
  /// Wraps `GET /rest/getArtist.view?id=<id>`. Returns one [Artist] with its
  /// `album` list populated. Family-keyed by artist id so the album-detail
  /// route can subscribe directly.
  ///
  /// L5: cache-aware. See [libraryAlbum] for the contract.
  ///
  /// Copied from [libraryArtist].
  const LibraryArtistFamily();

  /// Wraps `GET /rest/getArtist.view?id=<id>`. Returns one [Artist] with its
  /// `album` list populated. Family-keyed by artist id so the album-detail
  /// route can subscribe directly.
  ///
  /// L5: cache-aware. See [libraryAlbum] for the contract.
  ///
  /// Copied from [libraryArtist].
  LibraryArtistProvider call(String id) {
    return LibraryArtistProvider(id);
  }

  @override
  LibraryArtistProvider getProviderOverride(
    covariant LibraryArtistProvider provider,
  ) {
    return call(provider.id);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'libraryArtistProvider';
}

/// Wraps `GET /rest/getArtist.view?id=<id>`. Returns one [Artist] with its
/// `album` list populated. Family-keyed by artist id so the album-detail
/// route can subscribe directly.
///
/// L5: cache-aware. See [libraryAlbum] for the contract.
///
/// Copied from [libraryArtist].
class LibraryArtistProvider extends AutoDisposeFutureProvider<Artist> {
  /// Wraps `GET /rest/getArtist.view?id=<id>`. Returns one [Artist] with its
  /// `album` list populated. Family-keyed by artist id so the album-detail
  /// route can subscribe directly.
  ///
  /// L5: cache-aware. See [libraryAlbum] for the contract.
  ///
  /// Copied from [libraryArtist].
  LibraryArtistProvider(String id)
    : this._internal(
        (ref) => libraryArtist(ref as LibraryArtistRef, id),
        from: libraryArtistProvider,
        name: r'libraryArtistProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$libraryArtistHash,
        dependencies: LibraryArtistFamily._dependencies,
        allTransitiveDependencies:
            LibraryArtistFamily._allTransitiveDependencies,
        id: id,
      );

  LibraryArtistProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  Override overrideWith(
    FutureOr<Artist> Function(LibraryArtistRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: LibraryArtistProvider._internal(
        (ref) => create(ref as LibraryArtistRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Artist> createElement() {
    return _LibraryArtistProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LibraryArtistProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin LibraryArtistRef on AutoDisposeFutureProviderRef<Artist> {
  /// The parameter `id` of this provider.
  String get id;
}

class _LibraryArtistProviderElement
    extends AutoDisposeFutureProviderElement<Artist>
    with LibraryArtistRef {
  _LibraryArtistProviderElement(super.provider);

  @override
  String get id => (origin as LibraryArtistProvider).id;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
