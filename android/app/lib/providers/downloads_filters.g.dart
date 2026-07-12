// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'downloads_filters.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$downloadsSongSortNotifierHash() =>
    r'4b7417a0509a27abf0b539c77773bc8dbd3d9366';

/// See also [DownloadsSongSortNotifier].
@ProviderFor(DownloadsSongSortNotifier)
final downloadsSongSortNotifierProvider =
    AutoDisposeNotifierProvider<
      DownloadsSongSortNotifier,
      DownloadsSongSort
    >.internal(
      DownloadsSongSortNotifier.new,
      name: r'downloadsSongSortNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$downloadsSongSortNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$DownloadsSongSortNotifier = AutoDisposeNotifier<DownloadsSongSort>;
String _$downloadsAlbumSortNotifierHash() =>
    r'dc4b942d9492a43ebe98ec9764ec98daaa48c06d';

/// See also [DownloadsAlbumSortNotifier].
@ProviderFor(DownloadsAlbumSortNotifier)
final downloadsAlbumSortNotifierProvider =
    AutoDisposeNotifierProvider<
      DownloadsAlbumSortNotifier,
      DownloadsContainerSort
    >.internal(
      DownloadsAlbumSortNotifier.new,
      name: r'downloadsAlbumSortNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$downloadsAlbumSortNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$DownloadsAlbumSortNotifier =
    AutoDisposeNotifier<DownloadsContainerSort>;
String _$downloadsPlaylistSortNotifierHash() =>
    r'7a25de4da41e54d13cd50920f82cea20c4031b69';

/// See also [DownloadsPlaylistSortNotifier].
@ProviderFor(DownloadsPlaylistSortNotifier)
final downloadsPlaylistSortNotifierProvider =
    AutoDisposeNotifierProvider<
      DownloadsPlaylistSortNotifier,
      DownloadsContainerSort
    >.internal(
      DownloadsPlaylistSortNotifier.new,
      name: r'downloadsPlaylistSortNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$downloadsPlaylistSortNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$DownloadsPlaylistSortNotifier =
    AutoDisposeNotifier<DownloadsContainerSort>;
String _$downloadsLosslessOnlyNotifierHash() =>
    r'953ee1f1d4ed3a8957af647718a3e84b413e070c';

/// "Lossless" toggle (Songs tab only). D7: matches a suffix set, not just
/// `flac` — the DL6 join provider owns that logic; this notifier only holds
/// the on/off state.
///
/// Copied from [DownloadsLosslessOnlyNotifier].
@ProviderFor(DownloadsLosslessOnlyNotifier)
final downloadsLosslessOnlyNotifierProvider =
    AutoDisposeNotifierProvider<DownloadsLosslessOnlyNotifier, bool>.internal(
      DownloadsLosslessOnlyNotifier.new,
      name: r'downloadsLosslessOnlyNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$downloadsLosslessOnlyNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$DownloadsLosslessOnlyNotifier = AutoDisposeNotifier<bool>;
String _$downloadsTodayOnlyNotifierHash() =>
    r'a807359b2bf85a893b1bc9099e9156404bddde37';

/// "Today" toggle (Songs tab only) — filters to songs whose
/// `OfflineSongEntry.downloadedAt` falls on the current calendar day.
///
/// Copied from [DownloadsTodayOnlyNotifier].
@ProviderFor(DownloadsTodayOnlyNotifier)
final downloadsTodayOnlyNotifierProvider =
    AutoDisposeNotifierProvider<DownloadsTodayOnlyNotifier, bool>.internal(
      DownloadsTodayOnlyNotifier.new,
      name: r'downloadsTodayOnlyNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$downloadsTodayOnlyNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$DownloadsTodayOnlyNotifier = AutoDisposeNotifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
