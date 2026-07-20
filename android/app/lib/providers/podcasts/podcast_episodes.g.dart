// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'podcast_episodes.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$podcastEpisodesNotifierHash() =>
    r'ac4c68852b938172eaad5b1f01082dec3811fa48';

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

abstract class _$PodcastEpisodesNotifier
    extends BuildlessAutoDisposeAsyncNotifier<PodcastEpisodePage> {
  late final String channelId;

  FutureOr<PodcastEpisodePage> build(String channelId);
}

/// PC3 (#53): paginated episode list for one channel, family-keyed by
/// `channelId`. `build()` loads page 1; [loadMore] appends the next page;
/// [refresh] re-pulls the RSS feed server-side
/// (`POST /podcasts/channels/{id}/refresh`) before reloading page 1, so
/// pull-to-refresh actually picks up newly-published episodes rather than
/// just re-reading the same cached rows. [setSort] (PA2/PR3, #53) reloads
/// page 1 under a new `sort` — `newest`/`oldest`/`unplayed`, matching the
/// backend's `GET .../episodes?sort=` param.
///
/// Copied from [PodcastEpisodesNotifier].
@ProviderFor(PodcastEpisodesNotifier)
const podcastEpisodesNotifierProvider = PodcastEpisodesNotifierFamily();

/// PC3 (#53): paginated episode list for one channel, family-keyed by
/// `channelId`. `build()` loads page 1; [loadMore] appends the next page;
/// [refresh] re-pulls the RSS feed server-side
/// (`POST /podcasts/channels/{id}/refresh`) before reloading page 1, so
/// pull-to-refresh actually picks up newly-published episodes rather than
/// just re-reading the same cached rows. [setSort] (PA2/PR3, #53) reloads
/// page 1 under a new `sort` — `newest`/`oldest`/`unplayed`, matching the
/// backend's `GET .../episodes?sort=` param.
///
/// Copied from [PodcastEpisodesNotifier].
class PodcastEpisodesNotifierFamily
    extends Family<AsyncValue<PodcastEpisodePage>> {
  /// PC3 (#53): paginated episode list for one channel, family-keyed by
  /// `channelId`. `build()` loads page 1; [loadMore] appends the next page;
  /// [refresh] re-pulls the RSS feed server-side
  /// (`POST /podcasts/channels/{id}/refresh`) before reloading page 1, so
  /// pull-to-refresh actually picks up newly-published episodes rather than
  /// just re-reading the same cached rows. [setSort] (PA2/PR3, #53) reloads
  /// page 1 under a new `sort` — `newest`/`oldest`/`unplayed`, matching the
  /// backend's `GET .../episodes?sort=` param.
  ///
  /// Copied from [PodcastEpisodesNotifier].
  const PodcastEpisodesNotifierFamily();

  /// PC3 (#53): paginated episode list for one channel, family-keyed by
  /// `channelId`. `build()` loads page 1; [loadMore] appends the next page;
  /// [refresh] re-pulls the RSS feed server-side
  /// (`POST /podcasts/channels/{id}/refresh`) before reloading page 1, so
  /// pull-to-refresh actually picks up newly-published episodes rather than
  /// just re-reading the same cached rows. [setSort] (PA2/PR3, #53) reloads
  /// page 1 under a new `sort` — `newest`/`oldest`/`unplayed`, matching the
  /// backend's `GET .../episodes?sort=` param.
  ///
  /// Copied from [PodcastEpisodesNotifier].
  PodcastEpisodesNotifierProvider call(String channelId) {
    return PodcastEpisodesNotifierProvider(channelId);
  }

  @override
  PodcastEpisodesNotifierProvider getProviderOverride(
    covariant PodcastEpisodesNotifierProvider provider,
  ) {
    return call(provider.channelId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'podcastEpisodesNotifierProvider';
}

/// PC3 (#53): paginated episode list for one channel, family-keyed by
/// `channelId`. `build()` loads page 1; [loadMore] appends the next page;
/// [refresh] re-pulls the RSS feed server-side
/// (`POST /podcasts/channels/{id}/refresh`) before reloading page 1, so
/// pull-to-refresh actually picks up newly-published episodes rather than
/// just re-reading the same cached rows. [setSort] (PA2/PR3, #53) reloads
/// page 1 under a new `sort` — `newest`/`oldest`/`unplayed`, matching the
/// backend's `GET .../episodes?sort=` param.
///
/// Copied from [PodcastEpisodesNotifier].
class PodcastEpisodesNotifierProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          PodcastEpisodesNotifier,
          PodcastEpisodePage
        > {
  /// PC3 (#53): paginated episode list for one channel, family-keyed by
  /// `channelId`. `build()` loads page 1; [loadMore] appends the next page;
  /// [refresh] re-pulls the RSS feed server-side
  /// (`POST /podcasts/channels/{id}/refresh`) before reloading page 1, so
  /// pull-to-refresh actually picks up newly-published episodes rather than
  /// just re-reading the same cached rows. [setSort] (PA2/PR3, #53) reloads
  /// page 1 under a new `sort` — `newest`/`oldest`/`unplayed`, matching the
  /// backend's `GET .../episodes?sort=` param.
  ///
  /// Copied from [PodcastEpisodesNotifier].
  PodcastEpisodesNotifierProvider(String channelId)
    : this._internal(
        () => PodcastEpisodesNotifier()..channelId = channelId,
        from: podcastEpisodesNotifierProvider,
        name: r'podcastEpisodesNotifierProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$podcastEpisodesNotifierHash,
        dependencies: PodcastEpisodesNotifierFamily._dependencies,
        allTransitiveDependencies:
            PodcastEpisodesNotifierFamily._allTransitiveDependencies,
        channelId: channelId,
      );

  PodcastEpisodesNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.channelId,
  }) : super.internal();

  final String channelId;

  @override
  FutureOr<PodcastEpisodePage> runNotifierBuild(
    covariant PodcastEpisodesNotifier notifier,
  ) {
    return notifier.build(channelId);
  }

  @override
  Override overrideWith(PodcastEpisodesNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: PodcastEpisodesNotifierProvider._internal(
        () => create()..channelId = channelId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        channelId: channelId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<
    PodcastEpisodesNotifier,
    PodcastEpisodePage
  >
  createElement() {
    return _PodcastEpisodesNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PodcastEpisodesNotifierProvider &&
        other.channelId == channelId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, channelId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PodcastEpisodesNotifierRef
    on AutoDisposeAsyncNotifierProviderRef<PodcastEpisodePage> {
  /// The parameter `channelId` of this provider.
  String get channelId;
}

class _PodcastEpisodesNotifierProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<
          PodcastEpisodesNotifier,
          PodcastEpisodePage
        >
    with PodcastEpisodesNotifierRef {
  _PodcastEpisodesNotifierProviderElement(super.provider);

  @override
  String get channelId => (origin as PodcastEpisodesNotifierProvider).channelId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
