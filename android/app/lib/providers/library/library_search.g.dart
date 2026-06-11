// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_search.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$librarySearchHash() => r'5d6ac98c27552f4e6bfd555cd5ab6f63e16dd27e';

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

/// Wraps `GET /rest/search3.view?query=<q>`. Debounced via the existing
/// `searchDebounceProvider` (300ms by default) so rapid typing doesn't
/// hammer Navidrome.
///
/// Empty / whitespace-only queries short-circuit to an empty result without
/// firing a request. Mid-flight requests are cancelled when the query
/// changes via a `CancelToken` tied to `ref.onDispose`, mirroring the
/// existing YouTube-Music `searchResultsProvider`.
///
/// Copied from [librarySearch].
@ProviderFor(librarySearch)
const librarySearchProvider = LibrarySearchFamily();

/// Wraps `GET /rest/search3.view?query=<q>`. Debounced via the existing
/// `searchDebounceProvider` (300ms by default) so rapid typing doesn't
/// hammer Navidrome.
///
/// Empty / whitespace-only queries short-circuit to an empty result without
/// firing a request. Mid-flight requests are cancelled when the query
/// changes via a `CancelToken` tied to `ref.onDispose`, mirroring the
/// existing YouTube-Music `searchResultsProvider`.
///
/// Copied from [librarySearch].
class LibrarySearchFamily extends Family<AsyncValue<SearchResult3>> {
  /// Wraps `GET /rest/search3.view?query=<q>`. Debounced via the existing
  /// `searchDebounceProvider` (300ms by default) so rapid typing doesn't
  /// hammer Navidrome.
  ///
  /// Empty / whitespace-only queries short-circuit to an empty result without
  /// firing a request. Mid-flight requests are cancelled when the query
  /// changes via a `CancelToken` tied to `ref.onDispose`, mirroring the
  /// existing YouTube-Music `searchResultsProvider`.
  ///
  /// Copied from [librarySearch].
  const LibrarySearchFamily();

  /// Wraps `GET /rest/search3.view?query=<q>`. Debounced via the existing
  /// `searchDebounceProvider` (300ms by default) so rapid typing doesn't
  /// hammer Navidrome.
  ///
  /// Empty / whitespace-only queries short-circuit to an empty result without
  /// firing a request. Mid-flight requests are cancelled when the query
  /// changes via a `CancelToken` tied to `ref.onDispose`, mirroring the
  /// existing YouTube-Music `searchResultsProvider`.
  ///
  /// Copied from [librarySearch].
  LibrarySearchProvider call(String query) {
    return LibrarySearchProvider(query);
  }

  @override
  LibrarySearchProvider getProviderOverride(
    covariant LibrarySearchProvider provider,
  ) {
    return call(provider.query);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'librarySearchProvider';
}

/// Wraps `GET /rest/search3.view?query=<q>`. Debounced via the existing
/// `searchDebounceProvider` (300ms by default) so rapid typing doesn't
/// hammer Navidrome.
///
/// Empty / whitespace-only queries short-circuit to an empty result without
/// firing a request. Mid-flight requests are cancelled when the query
/// changes via a `CancelToken` tied to `ref.onDispose`, mirroring the
/// existing YouTube-Music `searchResultsProvider`.
///
/// Copied from [librarySearch].
class LibrarySearchProvider extends AutoDisposeFutureProvider<SearchResult3> {
  /// Wraps `GET /rest/search3.view?query=<q>`. Debounced via the existing
  /// `searchDebounceProvider` (300ms by default) so rapid typing doesn't
  /// hammer Navidrome.
  ///
  /// Empty / whitespace-only queries short-circuit to an empty result without
  /// firing a request. Mid-flight requests are cancelled when the query
  /// changes via a `CancelToken` tied to `ref.onDispose`, mirroring the
  /// existing YouTube-Music `searchResultsProvider`.
  ///
  /// Copied from [librarySearch].
  LibrarySearchProvider(String query)
    : this._internal(
        (ref) => librarySearch(ref as LibrarySearchRef, query),
        from: librarySearchProvider,
        name: r'librarySearchProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$librarySearchHash,
        dependencies: LibrarySearchFamily._dependencies,
        allTransitiveDependencies:
            LibrarySearchFamily._allTransitiveDependencies,
        query: query,
      );

  LibrarySearchProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.query,
  }) : super.internal();

  final String query;

  @override
  Override overrideWith(
    FutureOr<SearchResult3> Function(LibrarySearchRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: LibrarySearchProvider._internal(
        (ref) => create(ref as LibrarySearchRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        query: query,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<SearchResult3> createElement() {
    return _LibrarySearchProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LibrarySearchProvider && other.query == query;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, query.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin LibrarySearchRef on AutoDisposeFutureProviderRef<SearchResult3> {
  /// The parameter `query` of this provider.
  String get query;
}

class _LibrarySearchProviderElement
    extends AutoDisposeFutureProviderElement<SearchResult3>
    with LibrarySearchRef {
  _LibrarySearchProviderElement(super.provider);

  @override
  String get query => (origin as LibrarySearchProvider).query;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
