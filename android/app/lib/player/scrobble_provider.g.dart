// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scrobble_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$scrobbleHash() => r'f503fe68a4eb9c1369a9ffaaa2d22ea7afc44d3e';

/// Boots a [ScrobbleController] wired to the running [HeerrAudioHandler] +
/// the Subsonic dio client. Keep-alive so it survives screen rebuilds and
/// tracks every play across the session.
///
/// Read once at the root of the widget tree (see `HeerrApp.build`) to
/// trigger the subscription chain. The provider exposes nothing the UI
/// needs — its work is purely the side-effecting controller it owns. The
/// `Future<void>` shape lets the keep-alive scope clean up the controller
/// via `ref.onDispose`.
///
/// Copied from [scrobble].
@ProviderFor(scrobble)
final scrobbleProvider = FutureProvider<void>.internal(
  scrobble,
  name: r'scrobbleProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$scrobbleHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ScrobbleRef = FutureProviderRef<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
