import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_version.g.dart';

/// Human-readable app version for the Settings footer (#36), read from the
/// installed APK's versionName / versionCode (`v<version>+<build>`). These
/// come from pubspec `version:` unless overridden at build time — the
/// publish workflow passes the release tag via `--build-name`, so release
/// installs display the tag they were built from.
@Riverpod(keepAlive: true)
Future<String> appVersion(AppVersionRef ref) async {
  final PackageInfo info = await PackageInfo.fromPlatform();
  return info.buildNumber.isEmpty
      ? 'v${info.version}'
      : 'v${info.version}+${info.buildNumber}';
}
