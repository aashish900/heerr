// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_playlist.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$libraryPlaylistHash() => r'514a27e6dd8fc96de20f3935956a513885786724';

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

/// Wraps `GET /rest/getPlaylist.view?id=<id>`. Returns one [Playlist] with
/// its `entry` list populated (each entry is a song).
///
/// Copied from [libraryPlaylist].
@ProviderFor(libraryPlaylist)
const libraryPlaylistProvider = LibraryPlaylistFamily();

/// Wraps `GET /rest/getPlaylist.view?id=<id>`. Returns one [Playlist] with
/// its `entry` list populated (each entry is a song).
///
/// Copied from [libraryPlaylist].
class LibraryPlaylistFamily extends Family<AsyncValue<Playlist>> {
  /// Wraps `GET /rest/getPlaylist.view?id=<id>`. Returns one [Playlist] with
  /// its `entry` list populated (each entry is a song).
  ///
  /// Copied from [libraryPlaylist].
  const LibraryPlaylistFamily();

  /// Wraps `GET /rest/getPlaylist.view?id=<id>`. Returns one [Playlist] with
  /// its `entry` list populated (each entry is a song).
  ///
  /// Copied from [libraryPlaylist].
  LibraryPlaylistProvider call(String id) {
    return LibraryPlaylistProvider(id);
  }

  @override
  LibraryPlaylistProvider getProviderOverride(
    covariant LibraryPlaylistProvider provider,
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
  String? get name => r'libraryPlaylistProvider';
}

/// Wraps `GET /rest/getPlaylist.view?id=<id>`. Returns one [Playlist] with
/// its `entry` list populated (each entry is a song).
///
/// Copied from [libraryPlaylist].
class LibraryPlaylistProvider extends AutoDisposeFutureProvider<Playlist> {
  /// Wraps `GET /rest/getPlaylist.view?id=<id>`. Returns one [Playlist] with
  /// its `entry` list populated (each entry is a song).
  ///
  /// Copied from [libraryPlaylist].
  LibraryPlaylistProvider(String id)
    : this._internal(
        (ref) => libraryPlaylist(ref as LibraryPlaylistRef, id),
        from: libraryPlaylistProvider,
        name: r'libraryPlaylistProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$libraryPlaylistHash,
        dependencies: LibraryPlaylistFamily._dependencies,
        allTransitiveDependencies:
            LibraryPlaylistFamily._allTransitiveDependencies,
        id: id,
      );

  LibraryPlaylistProvider._internal(
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
    FutureOr<Playlist> Function(LibraryPlaylistRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: LibraryPlaylistProvider._internal(
        (ref) => create(ref as LibraryPlaylistRef),
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
  AutoDisposeFutureProviderElement<Playlist> createElement() {
    return _LibraryPlaylistProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LibraryPlaylistProvider && other.id == id;
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
mixin LibraryPlaylistRef on AutoDisposeFutureProviderRef<Playlist> {
  /// The parameter `id` of this provider.
  String get id;
}

class _LibraryPlaylistProviderElement
    extends AutoDisposeFutureProviderElement<Playlist>
    with LibraryPlaylistRef {
  _LibraryPlaylistProviderElement(super.provider);

  @override
  String get id => (origin as LibraryPlaylistProvider).id;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
