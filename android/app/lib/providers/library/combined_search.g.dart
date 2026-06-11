// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'combined_search.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$reindexGraceHash() => r'19496c77d8c22707a635ba7104610f5fd50a7eef';

/// See also [reindexGrace].
@ProviderFor(reindexGrace)
final reindexGraceProvider = Provider<Duration>.internal(
  reindexGrace,
  name: r'reindexGraceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$reindexGraceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ReindexGraceRef = ProviderRef<Duration>;
String _$combinedSearchHash() => r'082ecd054e2a46527ff0ffb5b419fb5d206b4890';

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

/// Orchestrates the two search sources behind the Library tab's search field.
///
/// Behaviour:
///   1. Always fires [librarySearchProvider(query)] (the Subsonic side).
///   2. Fires [ytmSearchProvider(query)] when either:
///      a. the library half came back empty (auto-fire), or
///      b. the user explicitly opted in via [ytmManualTriggerProvider].
///   3. Subscribes to [queueProvider] for the duration of the search and,
///      whenever a job transitions to `done`, schedules a one-shot
///      [librarySearchProvider(query)] invalidation [kReindexGrace] later so
///      a freshly-downloaded track auto-promotes from the YT section into
///      the library section.
///
/// `keepAlive: false` (default) — when the user navigates away from the
/// search results, the in-flight timers and queue subscription tear down
/// automatically.
///
/// Copied from [combinedSearch].
@ProviderFor(combinedSearch)
const combinedSearchProvider = CombinedSearchFamily();

/// Orchestrates the two search sources behind the Library tab's search field.
///
/// Behaviour:
///   1. Always fires [librarySearchProvider(query)] (the Subsonic side).
///   2. Fires [ytmSearchProvider(query)] when either:
///      a. the library half came back empty (auto-fire), or
///      b. the user explicitly opted in via [ytmManualTriggerProvider].
///   3. Subscribes to [queueProvider] for the duration of the search and,
///      whenever a job transitions to `done`, schedules a one-shot
///      [librarySearchProvider(query)] invalidation [kReindexGrace] later so
///      a freshly-downloaded track auto-promotes from the YT section into
///      the library section.
///
/// `keepAlive: false` (default) — when the user navigates away from the
/// search results, the in-flight timers and queue subscription tear down
/// automatically.
///
/// Copied from [combinedSearch].
class CombinedSearchFamily extends Family<CombinedSearchResult> {
  /// Orchestrates the two search sources behind the Library tab's search field.
  ///
  /// Behaviour:
  ///   1. Always fires [librarySearchProvider(query)] (the Subsonic side).
  ///   2. Fires [ytmSearchProvider(query)] when either:
  ///      a. the library half came back empty (auto-fire), or
  ///      b. the user explicitly opted in via [ytmManualTriggerProvider].
  ///   3. Subscribes to [queueProvider] for the duration of the search and,
  ///      whenever a job transitions to `done`, schedules a one-shot
  ///      [librarySearchProvider(query)] invalidation [kReindexGrace] later so
  ///      a freshly-downloaded track auto-promotes from the YT section into
  ///      the library section.
  ///
  /// `keepAlive: false` (default) — when the user navigates away from the
  /// search results, the in-flight timers and queue subscription tear down
  /// automatically.
  ///
  /// Copied from [combinedSearch].
  const CombinedSearchFamily();

  /// Orchestrates the two search sources behind the Library tab's search field.
  ///
  /// Behaviour:
  ///   1. Always fires [librarySearchProvider(query)] (the Subsonic side).
  ///   2. Fires [ytmSearchProvider(query)] when either:
  ///      a. the library half came back empty (auto-fire), or
  ///      b. the user explicitly opted in via [ytmManualTriggerProvider].
  ///   3. Subscribes to [queueProvider] for the duration of the search and,
  ///      whenever a job transitions to `done`, schedules a one-shot
  ///      [librarySearchProvider(query)] invalidation [kReindexGrace] later so
  ///      a freshly-downloaded track auto-promotes from the YT section into
  ///      the library section.
  ///
  /// `keepAlive: false` (default) — when the user navigates away from the
  /// search results, the in-flight timers and queue subscription tear down
  /// automatically.
  ///
  /// Copied from [combinedSearch].
  CombinedSearchProvider call(String query) {
    return CombinedSearchProvider(query);
  }

  @override
  CombinedSearchProvider getProviderOverride(
    covariant CombinedSearchProvider provider,
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
  String? get name => r'combinedSearchProvider';
}

/// Orchestrates the two search sources behind the Library tab's search field.
///
/// Behaviour:
///   1. Always fires [librarySearchProvider(query)] (the Subsonic side).
///   2. Fires [ytmSearchProvider(query)] when either:
///      a. the library half came back empty (auto-fire), or
///      b. the user explicitly opted in via [ytmManualTriggerProvider].
///   3. Subscribes to [queueProvider] for the duration of the search and,
///      whenever a job transitions to `done`, schedules a one-shot
///      [librarySearchProvider(query)] invalidation [kReindexGrace] later so
///      a freshly-downloaded track auto-promotes from the YT section into
///      the library section.
///
/// `keepAlive: false` (default) — when the user navigates away from the
/// search results, the in-flight timers and queue subscription tear down
/// automatically.
///
/// Copied from [combinedSearch].
class CombinedSearchProvider extends AutoDisposeProvider<CombinedSearchResult> {
  /// Orchestrates the two search sources behind the Library tab's search field.
  ///
  /// Behaviour:
  ///   1. Always fires [librarySearchProvider(query)] (the Subsonic side).
  ///   2. Fires [ytmSearchProvider(query)] when either:
  ///      a. the library half came back empty (auto-fire), or
  ///      b. the user explicitly opted in via [ytmManualTriggerProvider].
  ///   3. Subscribes to [queueProvider] for the duration of the search and,
  ///      whenever a job transitions to `done`, schedules a one-shot
  ///      [librarySearchProvider(query)] invalidation [kReindexGrace] later so
  ///      a freshly-downloaded track auto-promotes from the YT section into
  ///      the library section.
  ///
  /// `keepAlive: false` (default) — when the user navigates away from the
  /// search results, the in-flight timers and queue subscription tear down
  /// automatically.
  ///
  /// Copied from [combinedSearch].
  CombinedSearchProvider(String query)
    : this._internal(
        (ref) => combinedSearch(ref as CombinedSearchRef, query),
        from: combinedSearchProvider,
        name: r'combinedSearchProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$combinedSearchHash,
        dependencies: CombinedSearchFamily._dependencies,
        allTransitiveDependencies:
            CombinedSearchFamily._allTransitiveDependencies,
        query: query,
      );

  CombinedSearchProvider._internal(
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
    CombinedSearchResult Function(CombinedSearchRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CombinedSearchProvider._internal(
        (ref) => create(ref as CombinedSearchRef),
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
  AutoDisposeProviderElement<CombinedSearchResult> createElement() {
    return _CombinedSearchProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CombinedSearchProvider && other.query == query;
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
mixin CombinedSearchRef on AutoDisposeProviderRef<CombinedSearchResult> {
  /// The parameter `query` of this provider.
  String get query;
}

class _CombinedSearchProviderElement
    extends AutoDisposeProviderElement<CombinedSearchResult>
    with CombinedSearchRef {
  _CombinedSearchProviderElement(super.provider);

  @override
  String get query => (origin as CombinedSearchProvider).query;
}

String _$ytmManualTriggerHash() => r'12ccaa1b41250565f306e743e008891b31642776';

/// Set of queries the user has explicitly opted into firing a YouTube-Music
/// search for. Auto-fire (when the library result is empty) bypasses this;
/// this set is only consulted when the library half *did* return results
/// and the user tapped "Search more on YouTube Music".
///
/// Copied from [YtmManualTrigger].
@ProviderFor(YtmManualTrigger)
final ytmManualTriggerProvider =
    NotifierProvider<YtmManualTrigger, Set<String>>.internal(
      YtmManualTrigger.new,
      name: r'ytmManualTriggerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$ytmManualTriggerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$YtmManualTrigger = Notifier<Set<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
