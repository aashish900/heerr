// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_uri.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$localUriForHash() => r'1268ebca78a386c52bf2c4930fdf18fb7e14dd65';

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

/// Single chokepoint that the playback layer queries to decide whether to
/// open a local file or stream over the network.
///
/// Returns:
/// - `null` when the offline master switch is OFF (treat as stream-only).
/// - `null` when there's no manifest entry for [songId].
/// - `null` when the entry exists but state is not [OfflineSongState.ready].
/// - A `file://` URI string when the entry is `ready` with a `localPath`.
///
/// `playback_actions._toMediaItem` reads this and forwards the result to
/// `songToMediaItem(localFilePath: ...)`. Every play surface funnels through
/// that helper, so this provider is the only place that decides local vs.
/// stream.
///
/// Copied from [localUriFor].
@ProviderFor(localUriFor)
const localUriForProvider = LocalUriForFamily();

/// Single chokepoint that the playback layer queries to decide whether to
/// open a local file or stream over the network.
///
/// Returns:
/// - `null` when the offline master switch is OFF (treat as stream-only).
/// - `null` when there's no manifest entry for [songId].
/// - `null` when the entry exists but state is not [OfflineSongState.ready].
/// - A `file://` URI string when the entry is `ready` with a `localPath`.
///
/// `playback_actions._toMediaItem` reads this and forwards the result to
/// `songToMediaItem(localFilePath: ...)`. Every play surface funnels through
/// that helper, so this provider is the only place that decides local vs.
/// stream.
///
/// Copied from [localUriFor].
class LocalUriForFamily extends Family<String?> {
  /// Single chokepoint that the playback layer queries to decide whether to
  /// open a local file or stream over the network.
  ///
  /// Returns:
  /// - `null` when the offline master switch is OFF (treat as stream-only).
  /// - `null` when there's no manifest entry for [songId].
  /// - `null` when the entry exists but state is not [OfflineSongState.ready].
  /// - A `file://` URI string when the entry is `ready` with a `localPath`.
  ///
  /// `playback_actions._toMediaItem` reads this and forwards the result to
  /// `songToMediaItem(localFilePath: ...)`. Every play surface funnels through
  /// that helper, so this provider is the only place that decides local vs.
  /// stream.
  ///
  /// Copied from [localUriFor].
  const LocalUriForFamily();

  /// Single chokepoint that the playback layer queries to decide whether to
  /// open a local file or stream over the network.
  ///
  /// Returns:
  /// - `null` when the offline master switch is OFF (treat as stream-only).
  /// - `null` when there's no manifest entry for [songId].
  /// - `null` when the entry exists but state is not [OfflineSongState.ready].
  /// - A `file://` URI string when the entry is `ready` with a `localPath`.
  ///
  /// `playback_actions._toMediaItem` reads this and forwards the result to
  /// `songToMediaItem(localFilePath: ...)`. Every play surface funnels through
  /// that helper, so this provider is the only place that decides local vs.
  /// stream.
  ///
  /// Copied from [localUriFor].
  LocalUriForProvider call(String songId) {
    return LocalUriForProvider(songId);
  }

  @override
  LocalUriForProvider getProviderOverride(
    covariant LocalUriForProvider provider,
  ) {
    return call(provider.songId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'localUriForProvider';
}

/// Single chokepoint that the playback layer queries to decide whether to
/// open a local file or stream over the network.
///
/// Returns:
/// - `null` when the offline master switch is OFF (treat as stream-only).
/// - `null` when there's no manifest entry for [songId].
/// - `null` when the entry exists but state is not [OfflineSongState.ready].
/// - A `file://` URI string when the entry is `ready` with a `localPath`.
///
/// `playback_actions._toMediaItem` reads this and forwards the result to
/// `songToMediaItem(localFilePath: ...)`. Every play surface funnels through
/// that helper, so this provider is the only place that decides local vs.
/// stream.
///
/// Copied from [localUriFor].
class LocalUriForProvider extends AutoDisposeProvider<String?> {
  /// Single chokepoint that the playback layer queries to decide whether to
  /// open a local file or stream over the network.
  ///
  /// Returns:
  /// - `null` when the offline master switch is OFF (treat as stream-only).
  /// - `null` when there's no manifest entry for [songId].
  /// - `null` when the entry exists but state is not [OfflineSongState.ready].
  /// - A `file://` URI string when the entry is `ready` with a `localPath`.
  ///
  /// `playback_actions._toMediaItem` reads this and forwards the result to
  /// `songToMediaItem(localFilePath: ...)`. Every play surface funnels through
  /// that helper, so this provider is the only place that decides local vs.
  /// stream.
  ///
  /// Copied from [localUriFor].
  LocalUriForProvider(String songId)
    : this._internal(
        (ref) => localUriFor(ref as LocalUriForRef, songId),
        from: localUriForProvider,
        name: r'localUriForProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$localUriForHash,
        dependencies: LocalUriForFamily._dependencies,
        allTransitiveDependencies: LocalUriForFamily._allTransitiveDependencies,
        songId: songId,
      );

  LocalUriForProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.songId,
  }) : super.internal();

  final String songId;

  @override
  Override overrideWith(String? Function(LocalUriForRef provider) create) {
    return ProviderOverride(
      origin: this,
      override: LocalUriForProvider._internal(
        (ref) => create(ref as LocalUriForRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        songId: songId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<String?> createElement() {
    return _LocalUriForProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LocalUriForProvider && other.songId == songId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, songId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin LocalUriForRef on AutoDisposeProviderRef<String?> {
  /// The parameter `songId` of this provider.
  String get songId;
}

class _LocalUriForProviderElement extends AutoDisposeProviderElement<String?>
    with LocalUriForRef {
  _LocalUriForProviderElement(super.provider);

  @override
  String get songId => (origin as LocalUriForProvider).songId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
