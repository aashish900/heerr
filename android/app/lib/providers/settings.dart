import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'secure_storage.dart';

part 'settings.g.dart';

/// Persisted client settings — what the user pastes into the Settings screen
/// at first launch. Stored via `flutter_secure_storage` so the bearer token
/// never lands in plaintext SharedPreferences (decided in
/// `docs/DECISIONLOG.md` 2026-06-09 "Token storage").
///
/// Record type rather than a freezed class — two strings with native value
/// equality, no codegen needed.
typedef SettingsValue = ({String? backendBaseUrl, String? bearerToken});

const String _kKeyUrl = 'backend_base_url';
const String _kKeyToken = 'bearer_token';

@riverpod
class Settings extends _$Settings {
  @override
  Future<SettingsValue> build() async {
    final SecureStorage store = ref.read(secureStorageProvider);
    final String? url = await store.read(_kKeyUrl);
    final String? token = await store.read(_kKeyToken);
    return (backendBaseUrl: url, bearerToken: token);
  }

  /// Persist any provided value. Pass `null` for a field to leave it
  /// untouched (use [clear] to wipe both). The provider invalidates itself
  /// after writing so dependents (e.g. the dio client at B2) rebuild against
  /// the new values.
  ///
  /// Named `save` rather than `update` because `AsyncNotifierBase` already
  /// owns `update(...)` for mutating the cached AsyncValue — overriding it
  /// would break the type signature.
  Future<void> save({String? backendBaseUrl, String? bearerToken}) async {
    final SecureStorage store = ref.read(secureStorageProvider);
    if (backendBaseUrl != null) {
      await store.write(_kKeyUrl, backendBaseUrl);
    }
    if (bearerToken != null) {
      await store.write(_kKeyToken, bearerToken);
    }
    ref.invalidateSelf();
  }

  /// Wipe both keys. Used when the user revokes the token from the backend
  /// CLI and wants to clear the device state before pasting a fresh one.
  Future<void> clear() async {
    final SecureStorage store = ref.read(secureStorageProvider);
    await store.delete(_kKeyUrl);
    await store.delete(_kKeyToken);
    ref.invalidateSelf();
  }
}
