// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_registry.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$profileRegistryHash() => r'667ed7fb191512b9207c2318c770568a8c7d0755';

/// Persistent list of [Profile]s plus the currently-active id.
///
/// Reads and writes are routed through [SecureStorage] so the test
/// substitution mechanism used by `settings_test.dart` works here
/// unchanged. The notifier is the single chokepoint for every mutation
/// (add / remove / setActive / bumpLastUsed) so dependents can listen for
/// state changes via the normal Riverpod path.
///
/// The persisted JSON shape stores the full list under [kProfilesIndexKey];
/// the active id is stored independently under [kActiveProfileIdKey] so
/// switching the active profile doesn't rewrite the whole list.
///
/// Copied from [ProfileRegistry].
@ProviderFor(ProfileRegistry)
final profileRegistryProvider =
    AsyncNotifierProvider<ProfileRegistry, ProfileRegistryState>.internal(
      ProfileRegistry.new,
      name: r'profileRegistryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$profileRegistryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ProfileRegistry = AsyncNotifier<ProfileRegistryState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
