// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subsonic_client.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$subsonicDioClientHash() => r'1ae3aabcd734d3c4c7a42aac654d990a3813b957';

/// Builds a `Dio` for Subsonic calls against the user-configured Navidrome
/// base URL. Depends on [settingsProvider] so a saved credential change
/// invalidates and rebuilds with the new auth.
///
/// Copied from [subsonicDioClient].
@ProviderFor(subsonicDioClient)
final subsonicDioClientProvider = AutoDisposeFutureProvider<Dio>.internal(
  subsonicDioClient,
  name: r'subsonicDioClientProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$subsonicDioClientHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SubsonicDioClientRef = AutoDisposeFutureProviderRef<Dio>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
