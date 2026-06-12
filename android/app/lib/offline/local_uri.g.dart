// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_uri.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$localUriForHash() => r'7053cc9775a9a33a0e267e5916d961fb8099869c';

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
/// **Async on purpose.** Earlier this was a sync provider that read
/// `manifest.valueOrNull`. That gave a real bug: right after a sync
/// `ref.invalidate(offlineManifestProvider)` puts the manifest into a
/// loading state with the *previous* AsyncData snapshot attached. A
/// playback action that called `ref.read(localUriForProvider(songId))`
/// in that window saw the stale pre-sync manifest, didn't find a
/// `ready` entry, and quietly fell back to the stream URL — which then
/// failed offline. The user observed "I have to download twice for it
/// to play." Awaiting `manifest.future` blocks until the rebuild
/// completes (manifest is a disk read, fast even offline), so the
/// playback layer always sees the freshly persisted entry.
///
/// `playback_actions._toMediaItem` awaits this and forwards the result
/// to `songToMediaItem(localFilePath: ...)`. Every play surface funnels
/// through that helper, so this provider is the only place that decides
/// local vs. stream.
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
/// **Async on purpose.** Earlier this was a sync provider that read
/// `manifest.valueOrNull`. That gave a real bug: right after a sync
/// `ref.invalidate(offlineManifestProvider)` puts the manifest into a
/// loading state with the *previous* AsyncData snapshot attached. A
/// playback action that called `ref.read(localUriForProvider(songId))`
/// in that window saw the stale pre-sync manifest, didn't find a
/// `ready` entry, and quietly fell back to the stream URL — which then
/// failed offline. The user observed "I have to download twice for it
/// to play." Awaiting `manifest.future` blocks until the rebuild
/// completes (manifest is a disk read, fast even offline), so the
/// playback layer always sees the freshly persisted entry.
///
/// `playback_actions._toMediaItem` awaits this and forwards the result
/// to `songToMediaItem(localFilePath: ...)`. Every play surface funnels
/// through that helper, so this provider is the only place that decides
/// local vs. stream.
///
/// Copied from [localUriFor].
class LocalUriForFamily extends Family<AsyncValue<String?>> {
  /// Single chokepoint that the playback layer queries to decide whether to
  /// open a local file or stream over the network.
  ///
  /// Returns:
  /// - `null` when the offline master switch is OFF (treat as stream-only).
  /// - `null` when there's no manifest entry for [songId].
  /// - `null` when the entry exists but state is not [OfflineSongState.ready].
  /// - A `file://` URI string when the entry is `ready` with a `localPath`.
  ///
  /// **Async on purpose.** Earlier this was a sync provider that read
  /// `manifest.valueOrNull`. That gave a real bug: right after a sync
  /// `ref.invalidate(offlineManifestProvider)` puts the manifest into a
  /// loading state with the *previous* AsyncData snapshot attached. A
  /// playback action that called `ref.read(localUriForProvider(songId))`
  /// in that window saw the stale pre-sync manifest, didn't find a
  /// `ready` entry, and quietly fell back to the stream URL — which then
  /// failed offline. The user observed "I have to download twice for it
  /// to play." Awaiting `manifest.future` blocks until the rebuild
  /// completes (manifest is a disk read, fast even offline), so the
  /// playback layer always sees the freshly persisted entry.
  ///
  /// `playback_actions._toMediaItem` awaits this and forwards the result
  /// to `songToMediaItem(localFilePath: ...)`. Every play surface funnels
  /// through that helper, so this provider is the only place that decides
  /// local vs. stream.
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
  /// **Async on purpose.** Earlier this was a sync provider that read
  /// `manifest.valueOrNull`. That gave a real bug: right after a sync
  /// `ref.invalidate(offlineManifestProvider)` puts the manifest into a
  /// loading state with the *previous* AsyncData snapshot attached. A
  /// playback action that called `ref.read(localUriForProvider(songId))`
  /// in that window saw the stale pre-sync manifest, didn't find a
  /// `ready` entry, and quietly fell back to the stream URL — which then
  /// failed offline. The user observed "I have to download twice for it
  /// to play." Awaiting `manifest.future` blocks until the rebuild
  /// completes (manifest is a disk read, fast even offline), so the
  /// playback layer always sees the freshly persisted entry.
  ///
  /// `playback_actions._toMediaItem` awaits this and forwards the result
  /// to `songToMediaItem(localFilePath: ...)`. Every play surface funnels
  /// through that helper, so this provider is the only place that decides
  /// local vs. stream.
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
/// **Async on purpose.** Earlier this was a sync provider that read
/// `manifest.valueOrNull`. That gave a real bug: right after a sync
/// `ref.invalidate(offlineManifestProvider)` puts the manifest into a
/// loading state with the *previous* AsyncData snapshot attached. A
/// playback action that called `ref.read(localUriForProvider(songId))`
/// in that window saw the stale pre-sync manifest, didn't find a
/// `ready` entry, and quietly fell back to the stream URL — which then
/// failed offline. The user observed "I have to download twice for it
/// to play." Awaiting `manifest.future` blocks until the rebuild
/// completes (manifest is a disk read, fast even offline), so the
/// playback layer always sees the freshly persisted entry.
///
/// `playback_actions._toMediaItem` awaits this and forwards the result
/// to `songToMediaItem(localFilePath: ...)`. Every play surface funnels
/// through that helper, so this provider is the only place that decides
/// local vs. stream.
///
/// Copied from [localUriFor].
class LocalUriForProvider extends AutoDisposeFutureProvider<String?> {
  /// Single chokepoint that the playback layer queries to decide whether to
  /// open a local file or stream over the network.
  ///
  /// Returns:
  /// - `null` when the offline master switch is OFF (treat as stream-only).
  /// - `null` when there's no manifest entry for [songId].
  /// - `null` when the entry exists but state is not [OfflineSongState.ready].
  /// - A `file://` URI string when the entry is `ready` with a `localPath`.
  ///
  /// **Async on purpose.** Earlier this was a sync provider that read
  /// `manifest.valueOrNull`. That gave a real bug: right after a sync
  /// `ref.invalidate(offlineManifestProvider)` puts the manifest into a
  /// loading state with the *previous* AsyncData snapshot attached. A
  /// playback action that called `ref.read(localUriForProvider(songId))`
  /// in that window saw the stale pre-sync manifest, didn't find a
  /// `ready` entry, and quietly fell back to the stream URL — which then
  /// failed offline. The user observed "I have to download twice for it
  /// to play." Awaiting `manifest.future` blocks until the rebuild
  /// completes (manifest is a disk read, fast even offline), so the
  /// playback layer always sees the freshly persisted entry.
  ///
  /// `playback_actions._toMediaItem` awaits this and forwards the result
  /// to `songToMediaItem(localFilePath: ...)`. Every play surface funnels
  /// through that helper, so this provider is the only place that decides
  /// local vs. stream.
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
  Override overrideWith(
    FutureOr<String?> Function(LocalUriForRef provider) create,
  ) {
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
  AutoDisposeFutureProviderElement<String?> createElement() {
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
mixin LocalUriForRef on AutoDisposeFutureProviderRef<String?> {
  /// The parameter `songId` of this provider.
  String get songId;
}

class _LocalUriForProviderElement
    extends AutoDisposeFutureProviderElement<String?>
    with LocalUriForRef {
  _LocalUriForProviderElement(super.provider);

  @override
  String get songId => (origin as LocalUriForProvider).songId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
