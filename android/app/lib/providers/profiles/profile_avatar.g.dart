// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_avatar.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$avatarsDirHash() => r'5b44dded7a00741f1efc25659f0ed844ac9fa54c';

/// Directory holding avatar files — `<appDocs>/avatars/`. A provider seam
/// so tests substitute a temp dir.
///
/// Copied from [avatarsDir].
@ProviderFor(avatarsDir)
final avatarsDirProvider = FutureProvider<Directory>.internal(
  avatarsDir,
  name: r'avatarsDirProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$avatarsDirHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AvatarsDirRef = FutureProviderRef<Directory>;
String _$profileAvatarHash() => r'd89f19d62ce463ea7787b219e8bb9d5595f36d12';

/// The active profile's avatar file, or null when none is set (#37).
///
/// Files are named `<profileId>_<millis>.jpg` — a fresh path per change so
/// Flutter's path-keyed [FileImage] cache never serves a stale picture.
/// Old files for the same profile are swept on every write/remove. Keyed
/// per profile id, so switching profiles swaps avatars automatically
/// (watching [activeProfileProvider] rebuilds the lookup).
///
/// Copied from [ProfileAvatar].
@ProviderFor(ProfileAvatar)
final profileAvatarProvider =
    AsyncNotifierProvider<ProfileAvatar, File?>.internal(
      ProfileAvatar.new,
      name: r'profileAvatarProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$profileAvatarHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ProfileAvatar = AsyncNotifier<File?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
