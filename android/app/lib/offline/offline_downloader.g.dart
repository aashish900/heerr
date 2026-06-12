// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_downloader.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$offlineDownloadDioHash() =>
    r'f76e355353d6743f4a451ea81883d65161024da4';

/// A no-interceptor `Dio` for downloading audio bytes. Kept separate from
/// [subsonicDioClientProvider] because the Subsonic auth interceptor on that
/// instance would double-sign URLs that already carry their own
/// `u/s/t/v/c` params (see `buildSubsonicStreamUrl`).
///
/// Built without a `baseUrl` because [downloadSong] passes absolute URLs.
///
/// Copied from [offlineDownloadDio].
@ProviderFor(offlineDownloadDio)
final offlineDownloadDioProvider = Provider<Dio>.internal(
  offlineDownloadDio,
  name: r'offlineDownloadDioProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$offlineDownloadDioHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OfflineDownloadDioRef = ProviderRef<Dio>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
