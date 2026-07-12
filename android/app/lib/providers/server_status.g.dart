// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_status.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$serverStatusNotifierHash() =>
    r'ca4e5221e64c19f88212477bc896a7049d7a4f23';

/// Polls `BackendService.health()` every [_kPollInterval] while this
/// provider has a listener (autoDispose — the Downloads screen is the only
/// watcher, so polling stops the moment the user navigates away). No poll at
/// all when no profile is configured yet.
///
/// Copied from [ServerStatusNotifier].
@ProviderFor(ServerStatusNotifier)
final serverStatusNotifierProvider =
    AutoDisposeAsyncNotifierProvider<
      ServerStatusNotifier,
      ServerStatus
    >.internal(
      ServerStatusNotifier.new,
      name: r'serverStatusNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$serverStatusNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ServerStatusNotifier = AutoDisposeAsyncNotifier<ServerStatus>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
