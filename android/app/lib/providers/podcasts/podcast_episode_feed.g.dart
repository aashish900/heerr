// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'podcast_episode_feed.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$podcastEpisodeFeedHash() =>
    r'31d2a113652486a16e82cdf36b748084cc495645';

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

/// PA1/PR3 (#53): episodes across every show the calling user is
/// subscribed to, family-keyed by `filter` (`in_progress` / `latest` /
/// `downloaded` — matches the backend's `GET /podcasts/episodes?filter=`).
/// Backs Home's Continue Listening/Latest Episodes sections and the Library
/// Episodes/Downloads tabs — three call sites sharing one provider rather
/// than three near-identical ones. Fixed page size (20); none of PR3's
/// three call sites paginate.
///
/// Copied from [podcastEpisodeFeed].
@ProviderFor(podcastEpisodeFeed)
const podcastEpisodeFeedProvider = PodcastEpisodeFeedFamily();

/// PA1/PR3 (#53): episodes across every show the calling user is
/// subscribed to, family-keyed by `filter` (`in_progress` / `latest` /
/// `downloaded` — matches the backend's `GET /podcasts/episodes?filter=`).
/// Backs Home's Continue Listening/Latest Episodes sections and the Library
/// Episodes/Downloads tabs — three call sites sharing one provider rather
/// than three near-identical ones. Fixed page size (20); none of PR3's
/// three call sites paginate.
///
/// Copied from [podcastEpisodeFeed].
class PodcastEpisodeFeedFamily extends Family<AsyncValue<EpisodeFeedResponse>> {
  /// PA1/PR3 (#53): episodes across every show the calling user is
  /// subscribed to, family-keyed by `filter` (`in_progress` / `latest` /
  /// `downloaded` — matches the backend's `GET /podcasts/episodes?filter=`).
  /// Backs Home's Continue Listening/Latest Episodes sections and the Library
  /// Episodes/Downloads tabs — three call sites sharing one provider rather
  /// than three near-identical ones. Fixed page size (20); none of PR3's
  /// three call sites paginate.
  ///
  /// Copied from [podcastEpisodeFeed].
  const PodcastEpisodeFeedFamily();

  /// PA1/PR3 (#53): episodes across every show the calling user is
  /// subscribed to, family-keyed by `filter` (`in_progress` / `latest` /
  /// `downloaded` — matches the backend's `GET /podcasts/episodes?filter=`).
  /// Backs Home's Continue Listening/Latest Episodes sections and the Library
  /// Episodes/Downloads tabs — three call sites sharing one provider rather
  /// than three near-identical ones. Fixed page size (20); none of PR3's
  /// three call sites paginate.
  ///
  /// Copied from [podcastEpisodeFeed].
  PodcastEpisodeFeedProvider call(String filter) {
    return PodcastEpisodeFeedProvider(filter);
  }

  @override
  PodcastEpisodeFeedProvider getProviderOverride(
    covariant PodcastEpisodeFeedProvider provider,
  ) {
    return call(provider.filter);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'podcastEpisodeFeedProvider';
}

/// PA1/PR3 (#53): episodes across every show the calling user is
/// subscribed to, family-keyed by `filter` (`in_progress` / `latest` /
/// `downloaded` — matches the backend's `GET /podcasts/episodes?filter=`).
/// Backs Home's Continue Listening/Latest Episodes sections and the Library
/// Episodes/Downloads tabs — three call sites sharing one provider rather
/// than three near-identical ones. Fixed page size (20); none of PR3's
/// three call sites paginate.
///
/// Copied from [podcastEpisodeFeed].
class PodcastEpisodeFeedProvider
    extends AutoDisposeFutureProvider<EpisodeFeedResponse> {
  /// PA1/PR3 (#53): episodes across every show the calling user is
  /// subscribed to, family-keyed by `filter` (`in_progress` / `latest` /
  /// `downloaded` — matches the backend's `GET /podcasts/episodes?filter=`).
  /// Backs Home's Continue Listening/Latest Episodes sections and the Library
  /// Episodes/Downloads tabs — three call sites sharing one provider rather
  /// than three near-identical ones. Fixed page size (20); none of PR3's
  /// three call sites paginate.
  ///
  /// Copied from [podcastEpisodeFeed].
  PodcastEpisodeFeedProvider(String filter)
    : this._internal(
        (ref) => podcastEpisodeFeed(ref as PodcastEpisodeFeedRef, filter),
        from: podcastEpisodeFeedProvider,
        name: r'podcastEpisodeFeedProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$podcastEpisodeFeedHash,
        dependencies: PodcastEpisodeFeedFamily._dependencies,
        allTransitiveDependencies:
            PodcastEpisodeFeedFamily._allTransitiveDependencies,
        filter: filter,
      );

  PodcastEpisodeFeedProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.filter,
  }) : super.internal();

  final String filter;

  @override
  Override overrideWith(
    FutureOr<EpisodeFeedResponse> Function(PodcastEpisodeFeedRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PodcastEpisodeFeedProvider._internal(
        (ref) => create(ref as PodcastEpisodeFeedRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        filter: filter,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<EpisodeFeedResponse> createElement() {
    return _PodcastEpisodeFeedProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PodcastEpisodeFeedProvider && other.filter == filter;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, filter.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PodcastEpisodeFeedRef
    on AutoDisposeFutureProviderRef<EpisodeFeedResponse> {
  /// The parameter `filter` of this provider.
  String get filter;
}

class _PodcastEpisodeFeedProviderElement
    extends AutoDisposeFutureProviderElement<EpisodeFeedResponse>
    with PodcastEpisodeFeedRef {
  _PodcastEpisodeFeedProviderElement(super.provider);

  @override
  String get filter => (origin as PodcastEpisodeFeedProvider).filter;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
