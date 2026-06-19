// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prefs_storage.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$prefsStorageHash() => r'8445ecd747d3eabad153934ee101734d38a80531';

/// Riverpod provider returning the active [PrefsStorage] instance. Tests
/// override with `prefsStorageProvider.overrideWith((ref) => FakePrefs())`.
///
/// Copied from [prefsStorage].
@ProviderFor(prefsStorage)
final prefsStorageProvider = AutoDisposeProvider<PrefsStorage>.internal(
  prefsStorage,
  name: r'prefsStorageProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$prefsStorageHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PrefsStorageRef = AutoDisposeProviderRef<PrefsStorage>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
