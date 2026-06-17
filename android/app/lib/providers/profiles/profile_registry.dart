import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/profile.dart';
import '../secure_storage.dart';

part 'profile_registry.g.dart';

/// Secure-storage keys owned by the profile registry. Distinct from the
/// legacy `server_profiles` / `active_server_name` keys used by the
/// pre-Phase-S `ServerProfiles` notifier so the two systems can coexist
/// during the S3 migration window.
const String kProfilesIndexKey = 'profiles_index';
const String kActiveProfileIdKey = 'active_profile_id';

/// Wire-shape of the profiles index file persisted to secure storage —
/// `{"profiles": [<Profile.toJson()>, ...]}`. The list is the canonical
/// order in which Settings shows them.
typedef ProfileRegistryState = ({
  List<Profile> profiles,
  String? activeId,
});

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
@Riverpod(keepAlive: true)
class ProfileRegistry extends _$ProfileRegistry {
  @override
  Future<ProfileRegistryState> build() async {
    final SecureStorage store = ref.read(secureStorageProvider);
    final String? raw = await store.read(kProfilesIndexKey);
    final List<Profile> profiles = _decodeIndex(raw);
    final String? activeId = await store.read(kActiveProfileIdKey);
    return (profiles: profiles, activeId: _validateActive(profiles, activeId));
  }

  /// Insert or update [profile] by [Profile.id]. The newly-added/updated
  /// profile is appended (or replaces in-place) — preserves Settings list
  /// ordering for the existing entries.
  Future<void> addProfile(Profile profile) async {
    final ProfileRegistryState current = await future;
    final List<Profile> next = <Profile>[
      for (final Profile p in current.profiles)
        if (p.id != profile.id) p,
      profile,
    ];
    await _writeIndex(next);
    state = AsyncData((profiles: next, activeId: current.activeId));
  }

  /// Remove the profile with [id]. If it was active, the active pointer
  /// is cleared.
  Future<void> removeProfile(String id) async {
    final ProfileRegistryState current = await future;
    final List<Profile> next = <Profile>[
      for (final Profile p in current.profiles)
        if (p.id != id) p,
    ];
    await _writeIndex(next);
    String? activeId = current.activeId;
    if (activeId == id) {
      activeId = null;
      await ref.read(secureStorageProvider).delete(kActiveProfileIdKey);
    }
    state = AsyncData((profiles: next, activeId: activeId));
  }

  /// Set the active profile pointer. Passing `null` clears it (the next
  /// app launch should redirect to /login).
  Future<void> setActive(String? id) async {
    final ProfileRegistryState current = await future;
    if (id != null &&
        !current.profiles.any((Profile p) => p.id == id)) {
      throw StateError('cannot setActive($id) — id not in registry');
    }
    final SecureStorage store = ref.read(secureStorageProvider);
    if (id == null) {
      await store.delete(kActiveProfileIdKey);
    } else {
      await store.write(kActiveProfileIdKey, id);
    }
    state = AsyncData((profiles: current.profiles, activeId: id));
  }

  /// Refresh [Profile.lastUsedAt] for [id] to [now]. No-op if [id] is not
  /// in the registry.
  Future<void> bumpLastUsed(String id, {DateTime? now}) async {
    final ProfileRegistryState current = await future;
    final DateTime stamp = now ?? DateTime.now().toUtc();
    bool changed = false;
    final List<Profile> next = <Profile>[
      for (final Profile p in current.profiles)
        if (p.id == id)
          (() {
            changed = true;
            return p.copyWith(lastUsedAt: stamp);
          })()
        else
          p,
    ];
    if (!changed) return;
    await _writeIndex(next);
    state = AsyncData((profiles: next, activeId: current.activeId));
  }

  Future<void> _writeIndex(List<Profile> profiles) async {
    final SecureStorage store = ref.read(secureStorageProvider);
    final String json = jsonEncode(<String, Object?>{
      'profiles': profiles.map((Profile p) => p.toJson()).toList(),
    });
    await store.write(kProfilesIndexKey, json);
  }
}

/// Parse the persisted JSON. A missing / empty / corrupt blob yields an
/// empty list — the registry treats that the same as a fresh install and
/// the S5 router redirect pushes the user to `/login`.
List<Profile> _decodeIndex(String? raw) {
  if (raw == null || raw.isEmpty) return <Profile>[];
  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return <Profile>[];
    final Object? list = decoded['profiles'];
    if (list is! List) return <Profile>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(Profile.fromJson)
        .toList(growable: false);
  } on FormatException {
    return <Profile>[];
  }
}

/// Guard against a dangling active pointer: secure storage might have an
/// id whose Profile was deleted by some other path.
String? _validateActive(List<Profile> profiles, String? activeId) {
  if (activeId == null) return null;
  if (profiles.any((Profile p) => p.id == activeId)) return activeId;
  return null;
}
