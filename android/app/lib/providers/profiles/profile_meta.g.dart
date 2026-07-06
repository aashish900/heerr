// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_meta.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$profileMetaNotifierHash() =>
    r'c72f5f0ae4756dbe4e20fb6ae68d3722b3bc945e';

/// The active profile's optional display metadata (nickname + bio, #37).
///
/// Keyed per profile id in plain `shared_preferences` via [PrefsStorage]
/// (not the keystore — these aren't secrets, A5 rule). Watching
/// [activeProfileProvider] means a profile switch rebuilds this with the
/// new profile's meta automatically. No active profile → empty meta.
///
/// Copied from [ProfileMetaNotifier].
@ProviderFor(ProfileMetaNotifier)
final profileMetaNotifierProvider =
    AsyncNotifierProvider<ProfileMetaNotifier, ProfileMeta>.internal(
      ProfileMetaNotifier.new,
      name: r'profileMetaNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$profileMetaNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ProfileMetaNotifier = AsyncNotifier<ProfileMeta>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
