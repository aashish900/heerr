import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'secure_storage.dart';

part 'settings.g.dart';

/// Active backend + Navidrome credentials. heerr fields are the FastAPI
/// ingestion backend; navidrome fields are the Subsonic library/streaming
/// server (added at H1 for the streaming feature). All nullable so a
/// fresh install (no creds yet) is representable, and so a user that only
/// uses ingestion need not configure Navidrome.
typedef SettingsValue = ({
  String? backendBaseUrl,
  String? bearerToken,
  String? navidromeBaseUrl,
  String? navidromeUsername,
  String? navidromePassword,
});

const String _kKeyUrl = 'backend_base_url';
const String _kKeyToken = 'bearer_token';
const String _kKeyNavidromeUrl = 'navidrome_base_url';
const String _kKeyNavidromeUsername = 'navidrome_username';
const String _kKeyNavidromePassword = 'navidrome_password';
const String _kKeyProfiles = 'server_profiles';
const String _kKeyActiveName = 'active_server_name';

class ServerProfile {
  const ServerProfile({
    required this.name,
    required this.backendBaseUrl,
    required this.bearerToken,
    this.navidromeBaseUrl,
    this.navidromeUsername,
    this.navidromePassword,
  });

  final String name;
  final String backendBaseUrl;
  final String bearerToken;

  /// Navidrome (Subsonic) base URL — e.g. `http://100.106.120.121:4533`.
  /// Optional: a user that only uses ingestion need not configure it.
  final String? navidromeBaseUrl;
  final String? navidromeUsername;
  final String? navidromePassword;

  Map<String, String?> toJson() => <String, String?>{
        'name': name,
        'backendBaseUrl': backendBaseUrl,
        'bearerToken': bearerToken,
        'navidromeBaseUrl': navidromeBaseUrl,
        'navidromeUsername': navidromeUsername,
        'navidromePassword': navidromePassword,
      };

  factory ServerProfile.fromJson(Map<String, dynamic> j) => ServerProfile(
        name: j['name'] as String,
        backendBaseUrl: j['backendBaseUrl'] as String,
        bearerToken: j['bearerToken'] as String,
        navidromeBaseUrl: j['navidromeBaseUrl'] as String?,
        navidromeUsername: j['navidromeUsername'] as String?,
        navidromePassword: j['navidromePassword'] as String?,
      );
}

@riverpod
class Settings extends _$Settings {
  @override
  Future<SettingsValue> build() async {
    final SecureStorage store = ref.read(secureStorageProvider);
    final String? url = await store.read(_kKeyUrl);
    final String? token = await store.read(_kKeyToken);
    final String? nUrl = await store.read(_kKeyNavidromeUrl);
    final String? nUser = await store.read(_kKeyNavidromeUsername);
    final String? nPass = await store.read(_kKeyNavidromePassword);
    return (
      backendBaseUrl: url,
      bearerToken: token,
      navidromeBaseUrl: nUrl,
      navidromeUsername: nUser,
      navidromePassword: nPass,
    );
  }

  Future<void> save({
    String? backendBaseUrl,
    String? bearerToken,
    String? navidromeBaseUrl,
    String? navidromeUsername,
    String? navidromePassword,
  }) async {
    final SecureStorage store = ref.read(secureStorageProvider);
    if (backendBaseUrl != null) await store.write(_kKeyUrl, backendBaseUrl);
    if (bearerToken != null) await store.write(_kKeyToken, bearerToken);
    if (navidromeBaseUrl != null) {
      await store.write(_kKeyNavidromeUrl, navidromeBaseUrl);
    }
    if (navidromeUsername != null) {
      await store.write(_kKeyNavidromeUsername, navidromeUsername);
    }
    if (navidromePassword != null) {
      await store.write(_kKeyNavidromePassword, navidromePassword);
    }
    ref.invalidateSelf();
  }

  Future<void> clear() async {
    final SecureStorage store = ref.read(secureStorageProvider);
    await store.delete(_kKeyUrl);
    await store.delete(_kKeyToken);
    await store.delete(_kKeyNavidromeUrl);
    await store.delete(_kKeyNavidromeUsername);
    await store.delete(_kKeyNavidromePassword);
    ref.invalidateSelf();
  }
}

@riverpod
class ServerProfiles extends _$ServerProfiles {
  @override
  Future<List<ServerProfile>> build() async {
    final SecureStorage store = ref.read(secureStorageProvider);
    final String? raw = await store.read(_kKeyProfiles);
    if (raw == null) return <ServerProfile>[];
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((dynamic e) => ServerProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String?> activeName() async {
    return ref.read(secureStorageProvider).read(_kKeyActiveName);
  }

  /// Upsert by name, then make it the active server.
  Future<void> saveProfile(ServerProfile profile) async {
    final SecureStorage store = ref.read(secureStorageProvider);
    final List<ServerProfile> current = await future;
    final List<ServerProfile> updated = <ServerProfile>[
      for (final ServerProfile p in current)
        if (p.name != profile.name) p,
      profile,
    ];
    await store.write(
      _kKeyProfiles,
      jsonEncode(updated.map((ServerProfile p) => p.toJson()).toList()),
    );
    await store.write(_kKeyActiveName, profile.name);
    // Mirror into the active keys so dioClient + subsonicDioClient pick up
    // the change.
    await ref.read(settingsProvider.notifier).save(
          backendBaseUrl: profile.backendBaseUrl,
          bearerToken: profile.bearerToken,
          navidromeBaseUrl: profile.navidromeBaseUrl,
          navidromeUsername: profile.navidromeUsername,
          navidromePassword: profile.navidromePassword,
        );
    ref.invalidateSelf();
  }

  /// Load a saved profile into the active keys.
  Future<ServerProfile?> activate(String name) async {
    final List<ServerProfile> current = await future;
    final ServerProfile? profile =
        current.where((ServerProfile p) => p.name == name).firstOrNull;
    if (profile == null) return null;
    final SecureStorage store = ref.read(secureStorageProvider);
    await store.write(_kKeyActiveName, name);
    await ref.read(settingsProvider.notifier).save(
          backendBaseUrl: profile.backendBaseUrl,
          bearerToken: profile.bearerToken,
          navidromeBaseUrl: profile.navidromeBaseUrl,
          navidromeUsername: profile.navidromeUsername,
          navidromePassword: profile.navidromePassword,
        );
    return profile;
  }
}
