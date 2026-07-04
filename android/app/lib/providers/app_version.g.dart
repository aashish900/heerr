// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_version.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appVersionHash() => r'96391e1ef880d86896e22d8a33f3d71c6530ef8d';

/// Human-readable app version for the Settings footer (#36), read from the
/// installed APK's versionName / versionCode (`v<version>+<build>`). These
/// come from pubspec `version:` unless overridden at build time — the
/// publish workflow passes the release tag via `--build-name`, so release
/// installs display the tag they were built from.
///
/// Copied from [appVersion].
@ProviderFor(appVersion)
final appVersionProvider = FutureProvider<String>.internal(
  appVersion,
  name: r'appVersionProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$appVersionHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AppVersionRef = FutureProviderRef<String>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
