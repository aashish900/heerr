// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$searchDebounceHash() => r'b299e6ddbcd847cd680232b2bdafb3bee0459ae6';

/// Debounce duration applied to keystrokes before firing `/search`. Exposed
/// as a provider so widget tests can override it to `Duration.zero` and
/// avoid wall-clock delays.
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
String _$searchResultsHash() => r'f268698a30f675d97d60dd71708f746b73788c2b';

/// `POST /search` results for the current query. Empty query short-circuits
/// to an empty `SearchResponse` without hitting the network. Non-empty
/// queries are debounced (default 300ms) and any in-flight request is
/// cancelled when the query changes — via a `CancelToken` tied to
/// `ref.onDispose`.
///
/// Copied from [searchResults].
@ProviderFor(searchResults)
final searchResultsProvider =
    AutoDisposeFutureProvider<SearchResponse>.internal(
      searchResults,
      name: r'searchResultsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$searchResultsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SearchResultsRef = AutoDisposeFutureProviderRef<SearchResponse>;
String _$searchQueryHash() => r'2ac33fa639a7f8253042c9b7174393f66aa68057';

/// Search bar state. `keepAlive: true` because the user's last query should
/// survive tab switches (Search → Queue → Search).
///
/// Copied from [SearchQuery].
@ProviderFor(SearchQuery)
final searchQueryProvider =
    NotifierProvider<SearchQuery, SearchQueryState>.internal(
      SearchQuery.new,
      name: r'searchQueryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$searchQueryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SearchQuery = Notifier<SearchQueryState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
