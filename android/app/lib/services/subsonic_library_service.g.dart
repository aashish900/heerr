// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subsonic_library_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$subsonicLibraryServiceHash() =>
    r'fd2e368c0f77b633a254877b41867b0b1a5b3f66';

/// Async provider so the service is built once the (profile-keyed) Subsonic
/// [Dio] is ready. Tests that override `subsonicDioClientProvider` flow through
/// here unchanged — the service uses whatever dio that provider yields.
///
/// Copied from [subsonicLibraryService].
@ProviderFor(subsonicLibraryService)
final subsonicLibraryServiceProvider =
    AutoDisposeFutureProvider<SubsonicLibraryService>.internal(
      subsonicLibraryService,
      name: r'subsonicLibraryServiceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$subsonicLibraryServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SubsonicLibraryServiceRef =
    AutoDisposeFutureProviderRef<SubsonicLibraryService>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
