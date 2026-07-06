import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/profile.dart';
import '../../models/profile_meta.dart';
import '../prefs_storage.dart';
import 'active_profile.dart';

part 'profile_meta.g.dart';

/// PrefsStorage key prefix — full key is `profile_meta_<profileId>`.
const String kProfileMetaKeyPrefix = 'profile_meta_';

/// The active profile's optional display metadata (nickname + bio, #37).
///
/// Keyed per profile id in plain `shared_preferences` via [PrefsStorage]
/// (not the keystore — these aren't secrets, A5 rule). Watching
/// [activeProfileProvider] means a profile switch rebuilds this with the
/// new profile's meta automatically. No active profile → empty meta.
@Riverpod(keepAlive: true)
class ProfileMetaNotifier extends _$ProfileMetaNotifier {
  @override
  Future<ProfileMeta> build() async {
    final Profile? active = ref.watch(activeProfileProvider);
    if (active == null) return const ProfileMeta();
    final String? raw = await ref
        .read(prefsStorageProvider)
        .read('$kProfileMetaKeyPrefix${active.id}');
    return _decode(raw);
  }

  /// Persist nickname + bio for the active profile. Blank strings are
  /// stored as null — every field is optional. No-op without an active
  /// profile.
  Future<void> save({String? nickname, String? bio}) async {
    final Profile? active = ref.read(activeProfileProvider);
    if (active == null) return;
    final ProfileMeta meta = ProfileMeta(
      nickname: _blankToNull(nickname),
      bio: _blankToNull(bio),
    );
    await ref.read(prefsStorageProvider).write(
          '$kProfileMetaKeyPrefix${active.id}',
          jsonEncode(meta.toJson()),
        );
    state = AsyncData<ProfileMeta>(meta);
  }
}

String? _blankToNull(String? s) {
  if (s == null) return null;
  final String trimmed = s.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Tolerant decode — missing / corrupt JSON yields an empty meta rather
/// than an error (same posture as the profile registry's index decode).
ProfileMeta _decode(String? raw) {
  if (raw == null || raw.isEmpty) return const ProfileMeta();
  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return const ProfileMeta();
    return ProfileMeta.fromJson(decoded);
  } on FormatException {
    return const ProfileMeta();
  }
}
