// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mixes.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$mixVibesHash() => r'972831918854356d73297c135d7260b362d24d85';

/// The vibes the backend offers (`GET /recommend/mixes`, Phase MX). Static
/// server-side, so kept alive for the session.
///
/// Copied from [mixVibes].
@ProviderFor(mixVibes)
final mixVibesProvider = FutureProvider<List<MixVibe>>.internal(
  mixVibes,
  name: r'mixVibesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$mixVibesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MixVibesRef = FutureProviderRef<List<MixVibe>>;
String _$mixNotifierHash() => r'dbcd1240b1b2df5862a4dfd6ad9296c3a2206fbe';

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

abstract class _$MixNotifier extends BuildlessAsyncNotifier<MixResponse> {
  late final String id;

  FutureOr<MixResponse> build(String id);
}

/// One vibe's mix (`POST /recommend/mixes/{id}`), keyed by vibe id.
///
/// Sends the **whole** seed collection — unlike For You's sample of 8, a mix
/// is scored against the full taste profile — then drops songs already in the
/// library (same `search3` hydration as For You). Kept alive so reopening a
/// mix is instant; the backend caches the YTM side for 24h too.
///
/// Copied from [MixNotifier].
@ProviderFor(MixNotifier)
const mixNotifierProvider = MixNotifierFamily();

/// One vibe's mix (`POST /recommend/mixes/{id}`), keyed by vibe id.
///
/// Sends the **whole** seed collection — unlike For You's sample of 8, a mix
/// is scored against the full taste profile — then drops songs already in the
/// library (same `search3` hydration as For You). Kept alive so reopening a
/// mix is instant; the backend caches the YTM side for 24h too.
///
/// Copied from [MixNotifier].
class MixNotifierFamily extends Family<AsyncValue<MixResponse>> {
  /// One vibe's mix (`POST /recommend/mixes/{id}`), keyed by vibe id.
  ///
  /// Sends the **whole** seed collection — unlike For You's sample of 8, a mix
  /// is scored against the full taste profile — then drops songs already in the
  /// library (same `search3` hydration as For You). Kept alive so reopening a
  /// mix is instant; the backend caches the YTM side for 24h too.
  ///
  /// Copied from [MixNotifier].
  const MixNotifierFamily();

  /// One vibe's mix (`POST /recommend/mixes/{id}`), keyed by vibe id.
  ///
  /// Sends the **whole** seed collection — unlike For You's sample of 8, a mix
  /// is scored against the full taste profile — then drops songs already in the
  /// library (same `search3` hydration as For You). Kept alive so reopening a
  /// mix is instant; the backend caches the YTM side for 24h too.
  ///
  /// Copied from [MixNotifier].
  MixNotifierProvider call(String id) {
    return MixNotifierProvider(id);
  }

  @override
  MixNotifierProvider getProviderOverride(
    covariant MixNotifierProvider provider,
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
  String? get name => r'mixNotifierProvider';
}

/// One vibe's mix (`POST /recommend/mixes/{id}`), keyed by vibe id.
///
/// Sends the **whole** seed collection — unlike For You's sample of 8, a mix
/// is scored against the full taste profile — then drops songs already in the
/// library (same `search3` hydration as For You). Kept alive so reopening a
/// mix is instant; the backend caches the YTM side for 24h too.
///
/// Copied from [MixNotifier].
class MixNotifierProvider
    extends AsyncNotifierProviderImpl<MixNotifier, MixResponse> {
  /// One vibe's mix (`POST /recommend/mixes/{id}`), keyed by vibe id.
  ///
  /// Sends the **whole** seed collection — unlike For You's sample of 8, a mix
  /// is scored against the full taste profile — then drops songs already in the
  /// library (same `search3` hydration as For You). Kept alive so reopening a
  /// mix is instant; the backend caches the YTM side for 24h too.
  ///
  /// Copied from [MixNotifier].
  MixNotifierProvider(String id)
    : this._internal(
        () => MixNotifier()..id = id,
        from: mixNotifierProvider,
        name: r'mixNotifierProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$mixNotifierHash,
        dependencies: MixNotifierFamily._dependencies,
        allTransitiveDependencies: MixNotifierFamily._allTransitiveDependencies,
        id: id,
      );

  MixNotifierProvider._internal(
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
  FutureOr<MixResponse> runNotifierBuild(covariant MixNotifier notifier) {
    return notifier.build(id);
  }

  @override
  Override overrideWith(MixNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: MixNotifierProvider._internal(
        () => create()..id = id,
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
  AsyncNotifierProviderElement<MixNotifier, MixResponse> createElement() {
    return _MixNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MixNotifierProvider && other.id == id;
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
mixin MixNotifierRef on AsyncNotifierProviderRef<MixResponse> {
  /// The parameter `id` of this provider.
  String get id;
}

class _MixNotifierProviderElement
    extends AsyncNotifierProviderElement<MixNotifier, MixResponse>
    with MixNotifierRef {
  _MixNotifierProviderElement(super.provider);

  @override
  String get id => (origin as MixNotifierProvider).id;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
