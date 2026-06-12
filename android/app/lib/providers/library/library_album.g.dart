// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_album.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$libraryAlbumHash() => r'ad38efc1f439322943c97ae9a70217e7f8e44f4b';

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

/// Wraps `GET /rest/getAlbum.view?id=<id>`. Returns one [Album] with its
/// `song` list populated. Family-keyed by album id.
///
/// L5: cache-aware. On success the response is persisted to the per-server
/// library cache; on failure the cached copy is returned silently.
///
/// Copied from [libraryAlbum].
@ProviderFor(libraryAlbum)
const libraryAlbumProvider = LibraryAlbumFamily();

/// Wraps `GET /rest/getAlbum.view?id=<id>`. Returns one [Album] with its
/// `song` list populated. Family-keyed by album id.
///
/// L5: cache-aware. On success the response is persisted to the per-server
/// library cache; on failure the cached copy is returned silently.
///
/// Copied from [libraryAlbum].
class LibraryAlbumFamily extends Family<AsyncValue<Album>> {
  /// Wraps `GET /rest/getAlbum.view?id=<id>`. Returns one [Album] with its
  /// `song` list populated. Family-keyed by album id.
  ///
  /// L5: cache-aware. On success the response is persisted to the per-server
  /// library cache; on failure the cached copy is returned silently.
  ///
  /// Copied from [libraryAlbum].
  const LibraryAlbumFamily();

  /// Wraps `GET /rest/getAlbum.view?id=<id>`. Returns one [Album] with its
  /// `song` list populated. Family-keyed by album id.
  ///
  /// L5: cache-aware. On success the response is persisted to the per-server
  /// library cache; on failure the cached copy is returned silently.
  ///
  /// Copied from [libraryAlbum].
  LibraryAlbumProvider call(String id) {
    return LibraryAlbumProvider(id);
  }

  @override
  LibraryAlbumProvider getProviderOverride(
    covariant LibraryAlbumProvider provider,
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
  String? get name => r'libraryAlbumProvider';
}

/// Wraps `GET /rest/getAlbum.view?id=<id>`. Returns one [Album] with its
/// `song` list populated. Family-keyed by album id.
///
/// L5: cache-aware. On success the response is persisted to the per-server
/// library cache; on failure the cached copy is returned silently.
///
/// Copied from [libraryAlbum].
class LibraryAlbumProvider extends AutoDisposeFutureProvider<Album> {
  /// Wraps `GET /rest/getAlbum.view?id=<id>`. Returns one [Album] with its
  /// `song` list populated. Family-keyed by album id.
  ///
  /// L5: cache-aware. On success the response is persisted to the per-server
  /// library cache; on failure the cached copy is returned silently.
  ///
  /// Copied from [libraryAlbum].
  LibraryAlbumProvider(String id)
    : this._internal(
        (ref) => libraryAlbum(ref as LibraryAlbumRef, id),
        from: libraryAlbumProvider,
        name: r'libraryAlbumProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$libraryAlbumHash,
        dependencies: LibraryAlbumFamily._dependencies,
        allTransitiveDependencies:
            LibraryAlbumFamily._allTransitiveDependencies,
        id: id,
      );

  LibraryAlbumProvider._internal(
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
    FutureOr<Album> Function(LibraryAlbumRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: LibraryAlbumProvider._internal(
        (ref) => create(ref as LibraryAlbumRef),
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
  AutoDisposeFutureProviderElement<Album> createElement() {
    return _LibraryAlbumProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LibraryAlbumProvider && other.id == id;
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
mixin LibraryAlbumRef on AutoDisposeFutureProviderRef<Album> {
  /// The parameter `id` of this provider.
  String get id;
}

class _LibraryAlbumProviderElement
    extends AutoDisposeFutureProviderElement<Album>
    with LibraryAlbumRef {
  _LibraryAlbumProviderElement(super.provider);

  @override
  String get id => (origin as LibraryAlbumProvider).id;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
