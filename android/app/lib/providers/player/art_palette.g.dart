// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'art_palette.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$artPaletteHash() => r'4d13e728abd4993cf5a5700e7824beda5dc3c4f1';

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

/// Cached dominant-colour extraction for a cover-art URI (Part B —
/// HOMESCREEN.md §7 task B1).
///
/// Family keyed by the art URI string; keep-alive so each unique cover is
/// decoded + quantised exactly once per app session (palette extraction
/// decodes the whole image — that's the expensive step). Family keying also
/// kills the stale-response race the MiniPlayer used to guard by hand: a
/// late completion for an old URI lands in that URI's own provider entry
/// and can't clobber the current track's tint.
///
/// `null` = no extractable colour (fetch failed / bland cover) — callers
/// fall back to a brand colour.
///
/// Copied from [artPalette].
@ProviderFor(artPalette)
const artPaletteProvider = ArtPaletteFamily();

/// Cached dominant-colour extraction for a cover-art URI (Part B —
/// HOMESCREEN.md §7 task B1).
///
/// Family keyed by the art URI string; keep-alive so each unique cover is
/// decoded + quantised exactly once per app session (palette extraction
/// decodes the whole image — that's the expensive step). Family keying also
/// kills the stale-response race the MiniPlayer used to guard by hand: a
/// late completion for an old URI lands in that URI's own provider entry
/// and can't clobber the current track's tint.
///
/// `null` = no extractable colour (fetch failed / bland cover) — callers
/// fall back to a brand colour.
///
/// Copied from [artPalette].
class ArtPaletteFamily extends Family<AsyncValue<Color?>> {
  /// Cached dominant-colour extraction for a cover-art URI (Part B —
  /// HOMESCREEN.md §7 task B1).
  ///
  /// Family keyed by the art URI string; keep-alive so each unique cover is
  /// decoded + quantised exactly once per app session (palette extraction
  /// decodes the whole image — that's the expensive step). Family keying also
  /// kills the stale-response race the MiniPlayer used to guard by hand: a
  /// late completion for an old URI lands in that URI's own provider entry
  /// and can't clobber the current track's tint.
  ///
  /// `null` = no extractable colour (fetch failed / bland cover) — callers
  /// fall back to a brand colour.
  ///
  /// Copied from [artPalette].
  const ArtPaletteFamily();

  /// Cached dominant-colour extraction for a cover-art URI (Part B —
  /// HOMESCREEN.md §7 task B1).
  ///
  /// Family keyed by the art URI string; keep-alive so each unique cover is
  /// decoded + quantised exactly once per app session (palette extraction
  /// decodes the whole image — that's the expensive step). Family keying also
  /// kills the stale-response race the MiniPlayer used to guard by hand: a
  /// late completion for an old URI lands in that URI's own provider entry
  /// and can't clobber the current track's tint.
  ///
  /// `null` = no extractable colour (fetch failed / bland cover) — callers
  /// fall back to a brand colour.
  ///
  /// Copied from [artPalette].
  ArtPaletteProvider call(String artUri) {
    return ArtPaletteProvider(artUri);
  }

  @override
  ArtPaletteProvider getProviderOverride(
    covariant ArtPaletteProvider provider,
  ) {
    return call(provider.artUri);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'artPaletteProvider';
}

/// Cached dominant-colour extraction for a cover-art URI (Part B —
/// HOMESCREEN.md §7 task B1).
///
/// Family keyed by the art URI string; keep-alive so each unique cover is
/// decoded + quantised exactly once per app session (palette extraction
/// decodes the whole image — that's the expensive step). Family keying also
/// kills the stale-response race the MiniPlayer used to guard by hand: a
/// late completion for an old URI lands in that URI's own provider entry
/// and can't clobber the current track's tint.
///
/// `null` = no extractable colour (fetch failed / bland cover) — callers
/// fall back to a brand colour.
///
/// Copied from [artPalette].
class ArtPaletteProvider extends FutureProvider<Color?> {
  /// Cached dominant-colour extraction for a cover-art URI (Part B —
  /// HOMESCREEN.md §7 task B1).
  ///
  /// Family keyed by the art URI string; keep-alive so each unique cover is
  /// decoded + quantised exactly once per app session (palette extraction
  /// decodes the whole image — that's the expensive step). Family keying also
  /// kills the stale-response race the MiniPlayer used to guard by hand: a
  /// late completion for an old URI lands in that URI's own provider entry
  /// and can't clobber the current track's tint.
  ///
  /// `null` = no extractable colour (fetch failed / bland cover) — callers
  /// fall back to a brand colour.
  ///
  /// Copied from [artPalette].
  ArtPaletteProvider(String artUri)
    : this._internal(
        (ref) => artPalette(ref as ArtPaletteRef, artUri),
        from: artPaletteProvider,
        name: r'artPaletteProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$artPaletteHash,
        dependencies: ArtPaletteFamily._dependencies,
        allTransitiveDependencies: ArtPaletteFamily._allTransitiveDependencies,
        artUri: artUri,
      );

  ArtPaletteProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.artUri,
  }) : super.internal();

  final String artUri;

  @override
  Override overrideWith(
    FutureOr<Color?> Function(ArtPaletteRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ArtPaletteProvider._internal(
        (ref) => create(ref as ArtPaletteRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        artUri: artUri,
      ),
    );
  }

  @override
  FutureProviderElement<Color?> createElement() {
    return _ArtPaletteProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ArtPaletteProvider && other.artUri == artUri;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, artUri.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ArtPaletteRef on FutureProviderRef<Color?> {
  /// The parameter `artUri` of this provider.
  String get artUri;
}

class _ArtPaletteProviderElement extends FutureProviderElement<Color?>
    with ArtPaletteRef {
  _ArtPaletteProviderElement(super.provider);

  @override
  String get artUri => (origin as ArtPaletteProvider).artUri;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
