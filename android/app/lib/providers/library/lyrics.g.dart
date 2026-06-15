// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lyrics.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$lyricsForHash() => r'd5f609a4874de71426371e64ea5d5de0979559bb';

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

/// Wraps lyrics resolution for the Now Playing screen. P2.
///
/// Two-stage strategy:
///   1. `GET /rest/getLyricsBySongId.view?id=<songId>` against Navidrome
///      (Open Subsonic extension — uses LRCLib + embedded tags if configured).
///      Skipped when [songId] is empty.
///   2. If stage 1 returns null (code 70, empty list, or skipped), fall back
///      to `GET https://lrclib.net/api/get?artist_name=<artist>&track_name=<title>`
///      directly. Skipped when [artist] or [title] is empty.
///
/// Returns [Lyrics] with `value` set to plain text when lyrics are found,
/// or `null` when neither source has them. All other [ApiError]s from
/// Navidrome rethrow so the UI shows the error pane.
///
/// Copied from [lyricsFor].
@ProviderFor(lyricsFor)
const lyricsForProvider = LyricsForFamily();

/// Wraps lyrics resolution for the Now Playing screen. P2.
///
/// Two-stage strategy:
///   1. `GET /rest/getLyricsBySongId.view?id=<songId>` against Navidrome
///      (Open Subsonic extension — uses LRCLib + embedded tags if configured).
///      Skipped when [songId] is empty.
///   2. If stage 1 returns null (code 70, empty list, or skipped), fall back
///      to `GET https://lrclib.net/api/get?artist_name=<artist>&track_name=<title>`
///      directly. Skipped when [artist] or [title] is empty.
///
/// Returns [Lyrics] with `value` set to plain text when lyrics are found,
/// or `null` when neither source has them. All other [ApiError]s from
/// Navidrome rethrow so the UI shows the error pane.
///
/// Copied from [lyricsFor].
class LyricsForFamily extends Family<AsyncValue<Lyrics?>> {
  /// Wraps lyrics resolution for the Now Playing screen. P2.
  ///
  /// Two-stage strategy:
  ///   1. `GET /rest/getLyricsBySongId.view?id=<songId>` against Navidrome
  ///      (Open Subsonic extension — uses LRCLib + embedded tags if configured).
  ///      Skipped when [songId] is empty.
  ///   2. If stage 1 returns null (code 70, empty list, or skipped), fall back
  ///      to `GET https://lrclib.net/api/get?artist_name=<artist>&track_name=<title>`
  ///      directly. Skipped when [artist] or [title] is empty.
  ///
  /// Returns [Lyrics] with `value` set to plain text when lyrics are found,
  /// or `null` when neither source has them. All other [ApiError]s from
  /// Navidrome rethrow so the UI shows the error pane.
  ///
  /// Copied from [lyricsFor].
  const LyricsForFamily();

  /// Wraps lyrics resolution for the Now Playing screen. P2.
  ///
  /// Two-stage strategy:
  ///   1. `GET /rest/getLyricsBySongId.view?id=<songId>` against Navidrome
  ///      (Open Subsonic extension — uses LRCLib + embedded tags if configured).
  ///      Skipped when [songId] is empty.
  ///   2. If stage 1 returns null (code 70, empty list, or skipped), fall back
  ///      to `GET https://lrclib.net/api/get?artist_name=<artist>&track_name=<title>`
  ///      directly. Skipped when [artist] or [title] is empty.
  ///
  /// Returns [Lyrics] with `value` set to plain text when lyrics are found,
  /// or `null` when neither source has them. All other [ApiError]s from
  /// Navidrome rethrow so the UI shows the error pane.
  ///
  /// Copied from [lyricsFor].
  LyricsForProvider call(String songId, String artist, String title) {
    return LyricsForProvider(songId, artist, title);
  }

  @override
  LyricsForProvider getProviderOverride(covariant LyricsForProvider provider) {
    return call(provider.songId, provider.artist, provider.title);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'lyricsForProvider';
}

/// Wraps lyrics resolution for the Now Playing screen. P2.
///
/// Two-stage strategy:
///   1. `GET /rest/getLyricsBySongId.view?id=<songId>` against Navidrome
///      (Open Subsonic extension — uses LRCLib + embedded tags if configured).
///      Skipped when [songId] is empty.
///   2. If stage 1 returns null (code 70, empty list, or skipped), fall back
///      to `GET https://lrclib.net/api/get?artist_name=<artist>&track_name=<title>`
///      directly. Skipped when [artist] or [title] is empty.
///
/// Returns [Lyrics] with `value` set to plain text when lyrics are found,
/// or `null` when neither source has them. All other [ApiError]s from
/// Navidrome rethrow so the UI shows the error pane.
///
/// Copied from [lyricsFor].
class LyricsForProvider extends AutoDisposeFutureProvider<Lyrics?> {
  /// Wraps lyrics resolution for the Now Playing screen. P2.
  ///
  /// Two-stage strategy:
  ///   1. `GET /rest/getLyricsBySongId.view?id=<songId>` against Navidrome
  ///      (Open Subsonic extension — uses LRCLib + embedded tags if configured).
  ///      Skipped when [songId] is empty.
  ///   2. If stage 1 returns null (code 70, empty list, or skipped), fall back
  ///      to `GET https://lrclib.net/api/get?artist_name=<artist>&track_name=<title>`
  ///      directly. Skipped when [artist] or [title] is empty.
  ///
  /// Returns [Lyrics] with `value` set to plain text when lyrics are found,
  /// or `null` when neither source has them. All other [ApiError]s from
  /// Navidrome rethrow so the UI shows the error pane.
  ///
  /// Copied from [lyricsFor].
  LyricsForProvider(String songId, String artist, String title)
    : this._internal(
        (ref) => lyricsFor(ref as LyricsForRef, songId, artist, title),
        from: lyricsForProvider,
        name: r'lyricsForProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$lyricsForHash,
        dependencies: LyricsForFamily._dependencies,
        allTransitiveDependencies: LyricsForFamily._allTransitiveDependencies,
        songId: songId,
        artist: artist,
        title: title,
      );

  LyricsForProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.songId,
    required this.artist,
    required this.title,
  }) : super.internal();

  final String songId;
  final String artist;
  final String title;

  @override
  Override overrideWith(
    FutureOr<Lyrics?> Function(LyricsForRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: LyricsForProvider._internal(
        (ref) => create(ref as LyricsForRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        songId: songId,
        artist: artist,
        title: title,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Lyrics?> createElement() {
    return _LyricsForProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LyricsForProvider &&
        other.songId == songId &&
        other.artist == artist &&
        other.title == title;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, songId.hashCode);
    hash = _SystemHash.combine(hash, artist.hashCode);
    hash = _SystemHash.combine(hash, title.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin LyricsForRef on AutoDisposeFutureProviderRef<Lyrics?> {
  /// The parameter `songId` of this provider.
  String get songId;

  /// The parameter `artist` of this provider.
  String get artist;

  /// The parameter `title` of this provider.
  String get title;
}

class _LyricsForProviderElement
    extends AutoDisposeFutureProviderElement<Lyrics?>
    with LyricsForRef {
  _LyricsForProviderElement(super.provider);

  @override
  String get songId => (origin as LyricsForProvider).songId;
  @override
  String get artist => (origin as LyricsForProvider).artist;
  @override
  String get title => (origin as LyricsForProvider).title;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
