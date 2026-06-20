// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$searchDebounceHash() => r'b299e6ddbcd847cd680232b2bdafb3bee0459ae6';

/// Debounce applied to both the library and YouTube-Music search providers.
/// Exposed so tests can override it (typically to `Duration.zero`).
///
/// Copied from [searchDebounce].
@ProviderFor(searchDebounce)
final searchDebounceProvider = Provider<Duration>.internal(
  searchDebounce,
  name: r'searchDebounceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$searchDebounceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SearchDebounceRef = ProviderRef<Duration>;
String _$ytmSearchHash() => r'cccfa1b6fff81377da1c9bb5927db89a1023a2b6';

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

/// `POST /search` against the heerr backend (YouTube-Music search), via
/// [BackendService].
///
/// Family-keyed by the query string so the combined-search orchestrator can
/// pull the result for the current query directly.
///
/// Empty / whitespace-only queries short-circuit to an empty `SearchResponse`
/// without hitting the network. Non-empty queries are debounced (default
/// 300ms via [searchDebounceProvider]) and any in-flight request is cancelled
/// when the family key changes via a `CancelToken` tied to `ref.onDispose`.
///
/// Copied from [ytmSearch].
@ProviderFor(ytmSearch)
const ytmSearchProvider = YtmSearchFamily();

/// `POST /search` against the heerr backend (YouTube-Music search), via
/// [BackendService].
///
/// Family-keyed by the query string so the combined-search orchestrator can
/// pull the result for the current query directly.
///
/// Empty / whitespace-only queries short-circuit to an empty `SearchResponse`
/// without hitting the network. Non-empty queries are debounced (default
/// 300ms via [searchDebounceProvider]) and any in-flight request is cancelled
/// when the family key changes via a `CancelToken` tied to `ref.onDispose`.
///
/// Copied from [ytmSearch].
class YtmSearchFamily extends Family<AsyncValue<SearchResponse>> {
  /// `POST /search` against the heerr backend (YouTube-Music search), via
  /// [BackendService].
  ///
  /// Family-keyed by the query string so the combined-search orchestrator can
  /// pull the result for the current query directly.
  ///
  /// Empty / whitespace-only queries short-circuit to an empty `SearchResponse`
  /// without hitting the network. Non-empty queries are debounced (default
  /// 300ms via [searchDebounceProvider]) and any in-flight request is cancelled
  /// when the family key changes via a `CancelToken` tied to `ref.onDispose`.
  ///
  /// Copied from [ytmSearch].
  const YtmSearchFamily();

  /// `POST /search` against the heerr backend (YouTube-Music search), via
  /// [BackendService].
  ///
  /// Family-keyed by the query string so the combined-search orchestrator can
  /// pull the result for the current query directly.
  ///
  /// Empty / whitespace-only queries short-circuit to an empty `SearchResponse`
  /// without hitting the network. Non-empty queries are debounced (default
  /// 300ms via [searchDebounceProvider]) and any in-flight request is cancelled
  /// when the family key changes via a `CancelToken` tied to `ref.onDispose`.
  ///
  /// Copied from [ytmSearch].
  YtmSearchProvider call(String query) {
    return YtmSearchProvider(query);
  }

  @override
  YtmSearchProvider getProviderOverride(covariant YtmSearchProvider provider) {
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
  String? get name => r'ytmSearchProvider';
}

/// `POST /search` against the heerr backend (YouTube-Music search), via
/// [BackendService].
///
/// Family-keyed by the query string so the combined-search orchestrator can
/// pull the result for the current query directly.
///
/// Empty / whitespace-only queries short-circuit to an empty `SearchResponse`
/// without hitting the network. Non-empty queries are debounced (default
/// 300ms via [searchDebounceProvider]) and any in-flight request is cancelled
/// when the family key changes via a `CancelToken` tied to `ref.onDispose`.
///
/// Copied from [ytmSearch].
class YtmSearchProvider extends AutoDisposeFutureProvider<SearchResponse> {
  /// `POST /search` against the heerr backend (YouTube-Music search), via
  /// [BackendService].
  ///
  /// Family-keyed by the query string so the combined-search orchestrator can
  /// pull the result for the current query directly.
  ///
  /// Empty / whitespace-only queries short-circuit to an empty `SearchResponse`
  /// without hitting the network. Non-empty queries are debounced (default
  /// 300ms via [searchDebounceProvider]) and any in-flight request is cancelled
  /// when the family key changes via a `CancelToken` tied to `ref.onDispose`.
  ///
  /// Copied from [ytmSearch].
  YtmSearchProvider(String query)
    : this._internal(
        (ref) => ytmSearch(ref as YtmSearchRef, query),
        from: ytmSearchProvider,
        name: r'ytmSearchProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$ytmSearchHash,
        dependencies: YtmSearchFamily._dependencies,
        allTransitiveDependencies: YtmSearchFamily._allTransitiveDependencies,
        query: query,
      );

  YtmSearchProvider._internal(
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
    FutureOr<SearchResponse> Function(YtmSearchRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: YtmSearchProvider._internal(
        (ref) => create(ref as YtmSearchRef),
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
  AutoDisposeFutureProviderElement<SearchResponse> createElement() {
    return _YtmSearchProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is YtmSearchProvider && other.query == query;
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
mixin YtmSearchRef on AutoDisposeFutureProviderRef<SearchResponse> {
  /// The parameter `query` of this provider.
  String get query;
}

class _YtmSearchProviderElement
    extends AutoDisposeFutureProviderElement<SearchResponse>
    with YtmSearchRef {
  _YtmSearchProviderElement(super.provider);

  @override
  String get query => (origin as YtmSearchProvider).query;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
