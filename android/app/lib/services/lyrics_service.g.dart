// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lyrics_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$lyricsServiceHash() => r'318de4e324557dc5e62afd311e47b2d67efa6c5b';

/// Async provider so the service is built once the Subsonic [Dio] is ready.
/// Tests overriding `subsonicDioClientProvider` flow through unchanged.
///
/// Copied from [lyricsService].
@ProviderFor(lyricsService)
final lyricsServiceProvider = AutoDisposeFutureProvider<LyricsService>.internal(
  lyricsService,
  name: r'lyricsServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$lyricsServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LyricsServiceRef = AutoDisposeFutureProviderRef<LyricsService>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
