// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$dioClientHash() => r'd5d4692efef4198177e5597b23a6dfec6277326e';

/// Builds the app's `Dio` instance from the currently-loaded settings.
/// Depends on `settingsProvider` so the dio rebuilds whenever the user
/// saves a new backend URL or token. Returns a `Future` because settings
/// are loaded asynchronously from secure storage.
///
/// Copied from [dioClient].
@ProviderFor(dioClient)
final dioClientProvider = AutoDisposeFutureProvider<Dio>.internal(
  dioClient,
  name: r'dioClientProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$dioClientHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DioClientRef = AutoDisposeFutureProviderRef<Dio>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
