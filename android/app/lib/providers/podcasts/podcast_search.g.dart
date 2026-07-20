// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'podcast_search.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$podcastSearchHash() => r'e58bb4641a063a6323766b0789d7ad1ce1963b36';

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

/// PC2 (#53): `POST /podcasts/search` (Podcast Index), debounced the same
/// way as the online song search (`providers/search.dart::ytmSearch`) —
/// shares [searchDebounceProvider] rather than duplicating the constant.
///
/// Family-keyed by the query string. Empty/whitespace queries short-circuit
/// without hitting the network. Results have a null `PodcastChannel.id`
/// (not yet ingested) — the Discover screen matches against
/// `podcastSubscriptionsProvider` by `feedUrl` to know if a result is
/// already subscribed.
///
/// Copied from [podcastSearch].
@ProviderFor(podcastSearch)
const podcastSearchProvider = PodcastSearchFamily();

/// PC2 (#53): `POST /podcasts/search` (Podcast Index), debounced the same
/// way as the online song search (`providers/search.dart::ytmSearch`) —
/// shares [searchDebounceProvider] rather than duplicating the constant.
///
/// Family-keyed by the query string. Empty/whitespace queries short-circuit
/// without hitting the network. Results have a null `PodcastChannel.id`
/// (not yet ingested) — the Discover screen matches against
/// `podcastSubscriptionsProvider` by `feedUrl` to know if a result is
/// already subscribed.
///
/// Copied from [podcastSearch].
class PodcastSearchFamily extends Family<AsyncValue<List<PodcastChannel>>> {
  /// PC2 (#53): `POST /podcasts/search` (Podcast Index), debounced the same
  /// way as the online song search (`providers/search.dart::ytmSearch`) —
  /// shares [searchDebounceProvider] rather than duplicating the constant.
  ///
  /// Family-keyed by the query string. Empty/whitespace queries short-circuit
  /// without hitting the network. Results have a null `PodcastChannel.id`
  /// (not yet ingested) — the Discover screen matches against
  /// `podcastSubscriptionsProvider` by `feedUrl` to know if a result is
  /// already subscribed.
  ///
  /// Copied from [podcastSearch].
  const PodcastSearchFamily();

  /// PC2 (#53): `POST /podcasts/search` (Podcast Index), debounced the same
  /// way as the online song search (`providers/search.dart::ytmSearch`) —
  /// shares [searchDebounceProvider] rather than duplicating the constant.
  ///
  /// Family-keyed by the query string. Empty/whitespace queries short-circuit
  /// without hitting the network. Results have a null `PodcastChannel.id`
  /// (not yet ingested) — the Discover screen matches against
  /// `podcastSubscriptionsProvider` by `feedUrl` to know if a result is
  /// already subscribed.
  ///
  /// Copied from [podcastSearch].
  PodcastSearchProvider call(String query) {
    return PodcastSearchProvider(query);
  }

  @override
  PodcastSearchProvider getProviderOverride(
    covariant PodcastSearchProvider provider,
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
  String? get name => r'podcastSearchProvider';
}

/// PC2 (#53): `POST /podcasts/search` (Podcast Index), debounced the same
/// way as the online song search (`providers/search.dart::ytmSearch`) —
/// shares [searchDebounceProvider] rather than duplicating the constant.
///
/// Family-keyed by the query string. Empty/whitespace queries short-circuit
/// without hitting the network. Results have a null `PodcastChannel.id`
/// (not yet ingested) — the Discover screen matches against
/// `podcastSubscriptionsProvider` by `feedUrl` to know if a result is
/// already subscribed.
///
/// Copied from [podcastSearch].
class PodcastSearchProvider
    extends AutoDisposeFutureProvider<List<PodcastChannel>> {
  /// PC2 (#53): `POST /podcasts/search` (Podcast Index), debounced the same
  /// way as the online song search (`providers/search.dart::ytmSearch`) —
  /// shares [searchDebounceProvider] rather than duplicating the constant.
  ///
  /// Family-keyed by the query string. Empty/whitespace queries short-circuit
  /// without hitting the network. Results have a null `PodcastChannel.id`
  /// (not yet ingested) — the Discover screen matches against
  /// `podcastSubscriptionsProvider` by `feedUrl` to know if a result is
  /// already subscribed.
  ///
  /// Copied from [podcastSearch].
  PodcastSearchProvider(String query)
    : this._internal(
        (ref) => podcastSearch(ref as PodcastSearchRef, query),
        from: podcastSearchProvider,
        name: r'podcastSearchProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$podcastSearchHash,
        dependencies: PodcastSearchFamily._dependencies,
        allTransitiveDependencies:
            PodcastSearchFamily._allTransitiveDependencies,
        query: query,
      );

  PodcastSearchProvider._internal(
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
    FutureOr<List<PodcastChannel>> Function(PodcastSearchRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PodcastSearchProvider._internal(
        (ref) => create(ref as PodcastSearchRef),
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
  AutoDisposeFutureProviderElement<List<PodcastChannel>> createElement() {
    return _PodcastSearchProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PodcastSearchProvider && other.query == query;
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
mixin PodcastSearchRef on AutoDisposeFutureProviderRef<List<PodcastChannel>> {
  /// The parameter `query` of this provider.
  String get query;
}

class _PodcastSearchProviderElement
    extends AutoDisposeFutureProviderElement<List<PodcastChannel>>
    with PodcastSearchRef {
  _PodcastSearchProviderElement(super.provider);

  @override
  String get query => (origin as PodcastSearchProvider).query;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
