// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mix_saver.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$mixSaverHash() => r'52709e0a95b24648997f99fa9db43262bf681cb8';

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

abstract class _$MixSaver extends BuildlessNotifier<MixSaveState?> {
  late final String mixId;

  MixSaveState? build(String mixId);
}

/// "Save as playlist" for a vibe mix (Phase MX9), keyed by mix id. Kept alive
/// so leaving the mix screen doesn't cancel a multi-minute save.
///
/// 1. Create an empty Navidrome playlist "<title> · <d MMM>".
/// 2. Download every song ([_kParallel] at a time) and wait for each to be
///    indexed ([waitForLibrarySong]).
/// 3. Add the songs that made it, **in mix order**, in one call.
///
/// ponytail: an app kill mid-save leaves an empty/partial playlist (downloads
/// still finish server-side); persist the pending list if that ever matters.
///
/// Copied from [MixSaver].
@ProviderFor(MixSaver)
const mixSaverProvider = MixSaverFamily();

/// "Save as playlist" for a vibe mix (Phase MX9), keyed by mix id. Kept alive
/// so leaving the mix screen doesn't cancel a multi-minute save.
///
/// 1. Create an empty Navidrome playlist "<title> · <d MMM>".
/// 2. Download every song ([_kParallel] at a time) and wait for each to be
///    indexed ([waitForLibrarySong]).
/// 3. Add the songs that made it, **in mix order**, in one call.
///
/// ponytail: an app kill mid-save leaves an empty/partial playlist (downloads
/// still finish server-side); persist the pending list if that ever matters.
///
/// Copied from [MixSaver].
class MixSaverFamily extends Family<MixSaveState?> {
  /// "Save as playlist" for a vibe mix (Phase MX9), keyed by mix id. Kept alive
  /// so leaving the mix screen doesn't cancel a multi-minute save.
  ///
  /// 1. Create an empty Navidrome playlist "<title> · <d MMM>".
  /// 2. Download every song ([_kParallel] at a time) and wait for each to be
  ///    indexed ([waitForLibrarySong]).
  /// 3. Add the songs that made it, **in mix order**, in one call.
  ///
  /// ponytail: an app kill mid-save leaves an empty/partial playlist (downloads
  /// still finish server-side); persist the pending list if that ever matters.
  ///
  /// Copied from [MixSaver].
  const MixSaverFamily();

  /// "Save as playlist" for a vibe mix (Phase MX9), keyed by mix id. Kept alive
  /// so leaving the mix screen doesn't cancel a multi-minute save.
  ///
  /// 1. Create an empty Navidrome playlist "<title> · <d MMM>".
  /// 2. Download every song ([_kParallel] at a time) and wait for each to be
  ///    indexed ([waitForLibrarySong]).
  /// 3. Add the songs that made it, **in mix order**, in one call.
  ///
  /// ponytail: an app kill mid-save leaves an empty/partial playlist (downloads
  /// still finish server-side); persist the pending list if that ever matters.
  ///
  /// Copied from [MixSaver].
  MixSaverProvider call(String mixId) {
    return MixSaverProvider(mixId);
  }

  @override
  MixSaverProvider getProviderOverride(covariant MixSaverProvider provider) {
    return call(provider.mixId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'mixSaverProvider';
}

/// "Save as playlist" for a vibe mix (Phase MX9), keyed by mix id. Kept alive
/// so leaving the mix screen doesn't cancel a multi-minute save.
///
/// 1. Create an empty Navidrome playlist "<title> · <d MMM>".
/// 2. Download every song ([_kParallel] at a time) and wait for each to be
///    indexed ([waitForLibrarySong]).
/// 3. Add the songs that made it, **in mix order**, in one call.
///
/// ponytail: an app kill mid-save leaves an empty/partial playlist (downloads
/// still finish server-side); persist the pending list if that ever matters.
///
/// Copied from [MixSaver].
class MixSaverProvider extends NotifierProviderImpl<MixSaver, MixSaveState?> {
  /// "Save as playlist" for a vibe mix (Phase MX9), keyed by mix id. Kept alive
  /// so leaving the mix screen doesn't cancel a multi-minute save.
  ///
  /// 1. Create an empty Navidrome playlist "<title> · <d MMM>".
  /// 2. Download every song ([_kParallel] at a time) and wait for each to be
  ///    indexed ([waitForLibrarySong]).
  /// 3. Add the songs that made it, **in mix order**, in one call.
  ///
  /// ponytail: an app kill mid-save leaves an empty/partial playlist (downloads
  /// still finish server-side); persist the pending list if that ever matters.
  ///
  /// Copied from [MixSaver].
  MixSaverProvider(String mixId)
    : this._internal(
        () => MixSaver()..mixId = mixId,
        from: mixSaverProvider,
        name: r'mixSaverProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$mixSaverHash,
        dependencies: MixSaverFamily._dependencies,
        allTransitiveDependencies: MixSaverFamily._allTransitiveDependencies,
        mixId: mixId,
      );

  MixSaverProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.mixId,
  }) : super.internal();

  final String mixId;

  @override
  MixSaveState? runNotifierBuild(covariant MixSaver notifier) {
    return notifier.build(mixId);
  }

  @override
  Override overrideWith(MixSaver Function() create) {
    return ProviderOverride(
      origin: this,
      override: MixSaverProvider._internal(
        () => create()..mixId = mixId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        mixId: mixId,
      ),
    );
  }

  @override
  NotifierProviderElement<MixSaver, MixSaveState?> createElement() {
    return _MixSaverProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MixSaverProvider && other.mixId == mixId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, mixId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MixSaverRef on NotifierProviderRef<MixSaveState?> {
  /// The parameter `mixId` of this provider.
  String get mixId;
}

class _MixSaverProviderElement
    extends NotifierProviderElement<MixSaver, MixSaveState?>
    with MixSaverRef {
  _MixSaverProviderElement(super.provider);

  @override
  String get mixId => (origin as MixSaverProvider).mixId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
