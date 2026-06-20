// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlist_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$playlistServiceHash() => r'828182088dd1770d5b013e033918dc4ba23663b6';

/// Async provider so the service is built once the (profile-keyed) Subsonic
/// [Dio] is ready. Tests overriding `subsonicDioClientProvider` flow through.
///
/// Copied from [playlistService].
@ProviderFor(playlistService)
final playlistServiceProvider =
    AutoDisposeFutureProvider<PlaylistService>.internal(
      playlistService,
      name: r'playlistServiceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$playlistServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PlaylistServiceRef = AutoDisposeFutureProviderRef<PlaylistService>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
