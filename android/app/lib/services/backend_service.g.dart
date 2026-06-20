// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backend_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$backendServiceHash() => r'6fee6f56e90385f699aa6e34c8014043043e293b';

/// Async provider so the service is built once the bearer-auth [Dio] is ready.
/// Tests that override `dioClientProvider` flow through unchanged.
///
/// Copied from [backendService].
@ProviderFor(backendService)
final backendServiceProvider =
    AutoDisposeFutureProvider<BackendService>.internal(
      backendService,
      name: r'backendServiceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$backendServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BackendServiceRef = AutoDisposeFutureProviderRef<BackendService>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
