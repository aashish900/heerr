// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_paths.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$applicationDocumentsDirectoryHash() =>
    r'e1fa0df3a13273605f36b8d02ccc473c25220bc5';

/// Resolves the app-private documents directory once and caches it.
///
/// Test override: `applicationDocumentsDirectoryProvider.overrideWith(
///   (ref) async => Directory(tmp.path),
/// )`.
///
/// Copied from [applicationDocumentsDirectory].
@ProviderFor(applicationDocumentsDirectory)
final applicationDocumentsDirectoryProvider =
    FutureProvider<Directory>.internal(
      applicationDocumentsDirectory,
      name: r'applicationDocumentsDirectoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$applicationDocumentsDirectoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ApplicationDocumentsDirectoryRef = FutureProviderRef<Directory>;
String _$offlinePathsHash() => r'b5f627199eabbc8d8614f63270550dce9cc48115';

/// See also [offlinePaths].
@ProviderFor(offlinePaths)
final offlinePathsProvider = FutureProvider<OfflinePaths>.internal(
  offlinePaths,
  name: r'offlinePathsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$offlinePathsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OfflinePathsRef = FutureProviderRef<OfflinePaths>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
