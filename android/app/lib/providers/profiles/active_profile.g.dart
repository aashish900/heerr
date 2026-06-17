// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_profile.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$activeProfileHash() => r'a4d3f468d49724baee1566ac2502cefa35cd2020';

/// The currently-active [Profile], derived from [profileRegistryProvider].
///
/// Returns `null` when no profile is active (fresh install pre-login, or
/// after the user removed the active profile from Settings). Watchers
/// should treat `null` as "redirect to /login" — the router's
/// first-launch redirect (S5) handles that for routed navigation.
///
/// `Settings`-scoped fields that aren't per-profile (offline toggles,
/// sleep-timer defaults) continue to live in `settingsProvider`. Only
/// the per-server credential set moves under this provider.
///
/// Copied from [activeProfile].
@ProviderFor(activeProfile)
final activeProfileProvider = Provider<Profile?>.internal(
  activeProfile,
  name: r'activeProfileProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$activeProfileHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ActiveProfileRef = ProviderRef<Profile?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
