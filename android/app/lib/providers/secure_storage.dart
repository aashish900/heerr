import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'secure_storage.g.dart';

/// Thin abstraction over `flutter_secure_storage`. Lets tests substitute an
/// in-memory fake without touching the platform channel (Android
/// EncryptedSharedPreferences).
abstract class SecureStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Production impl. `AndroidOptions.encryptedSharedPreferences: true` is the
/// modern (>=23 API) backend — required by the v9.x package default but
/// stated explicitly so a future flutter_secure_storage major can't silently
/// downgrade us.
class FlutterSecureStorageImpl implements SecureStorage {
  FlutterSecureStorageImpl()
    : _store = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );

  final FlutterSecureStorage _store;

  @override
  Future<String?> read(String key) => _store.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _store.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _store.delete(key: key);
}

/// Riverpod provider returning the active `SecureStorage` instance. Tests
/// override with `secureStorageProvider.overrideWith((ref) => FakeSecureStorage())`.
@riverpod
SecureStorage secureStorage(SecureStorageRef ref) => FlutterSecureStorageImpl();
