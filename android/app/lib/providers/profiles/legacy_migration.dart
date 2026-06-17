import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/profile.dart';
import '../secure_storage.dart';
import 'profile_registry.dart';

/// Pre-Phase-S secure-storage keys for the single-set settings provider.
/// Kept here (not imported from `settings.dart`) so the migration shim
/// continues to compile if those constants are removed at a future
/// version bump.
const String kLegacyBackendBaseUrl = 'backend_base_url';
const String kLegacyBearerToken = 'bearer_token';
const String kLegacyNavidromeBaseUrl = 'navidrome_base_url';
const String kLegacyNavidromeUsername = 'navidrome_username';
const String kLegacyNavidromePassword = 'navidrome_password';

/// One-shot migration: detect a pre-S install that has legacy single-set
/// credentials in secure storage but no `profiles_index` blob → wrap the
/// legacy values as a [Profile], persist it via [ProfileRegistry], make it
/// the active profile, then delete the legacy keys.
///
/// Idempotent on three axes:
/// 1. Running it twice after a successful migration is a no-op — the
///    legacy keys are gone, so the "legacy present" precondition fails.
/// 2. Running it on a fresh install (no legacy keys, no profiles index)
///    is a no-op — no creds to wrap.
/// 3. Running it on a partially-set legacy install (heerr URL present
///    but Navidrome creds missing, or vice-versa) is a no-op — we only
///    migrate when *all five* legacy fields are present, because a
///    Profile contract requires all of them. Users in that state will be
///    redirected to /login (S5) which re-collects every field.
///
/// Returns the migrated [Profile] when a migration happened, else `null`.
Future<Profile?> migrateLegacyCreds(
  ProviderContainer container, {
  DateTime Function()? now,
  String Function()? newId,
}) async {
  final SecureStorage store = container.read(secureStorageProvider);

  // Skip if the registry already has any profile — implies a prior
  // migration ran or the user logged in fresh under Phase S.
  final String? indexBlob = await store.read(kProfilesIndexKey);
  if (indexBlob != null && indexBlob.isNotEmpty) return null;

  final String? heerrUrl = await store.read(kLegacyBackendBaseUrl);
  final String? heerrToken = await store.read(kLegacyBearerToken);
  final String? navUrl = await store.read(kLegacyNavidromeBaseUrl);
  final String? navUser = await store.read(kLegacyNavidromeUsername);
  final String? navPass = await store.read(kLegacyNavidromePassword);

  // All five required. Partial state → no migration; S5 login collects
  // the full set.
  // All five fields must be present *and* non-empty. An empty navidrome
  // username can't drive a real login at S5, so we treat it as missing
  // — partial state, no migration. The Profile contract also forbids
  // empty values via `required`.
  if (heerrUrl == null ||
      heerrUrl.isEmpty ||
      heerrToken == null ||
      heerrToken.isEmpty ||
      navUrl == null ||
      navUrl.isEmpty ||
      navUser == null ||
      navUser.isEmpty ||
      navPass == null ||
      navPass.isEmpty) {
    return null;
  }

  final DateTime stamp = (now ?? () => DateTime.now().toUtc())();
  final String id = (newId ?? _uuidV4)();
  final String displayName = navUser;

  final Profile profile = Profile(
    id: id,
    displayName: displayName,
    heerrBaseUrl: heerrUrl,
    heerrBearerToken: heerrToken,
    navidromeBaseUrl: navUrl,
    navidromeUsername: navUser,
    navidromePassword: navPass,
    createdAt: stamp,
    lastUsedAt: stamp,
  );

  // Persist via the notifier so any listening dependents (none yet in S3,
  // but S6+ will rely on this) see a normal state transition rather than
  // a hand-rolled blob write.
  await container
      .read(profileRegistryProvider.notifier)
      .addProfile(profile);
  await container.read(profileRegistryProvider.notifier).setActive(id);

  // Sweep the legacy keys so a re-run is a no-op and the Settings
  // provider doesn't keep reading stale single-set creds alongside the
  // profile.
  await store.delete(kLegacyBackendBaseUrl);
  await store.delete(kLegacyBearerToken);
  await store.delete(kLegacyNavidromeBaseUrl);
  await store.delete(kLegacyNavidromeUsername);
  await store.delete(kLegacyNavidromePassword);

  return profile;
}

/// RFC 4122 v4 UUID. Inlined to avoid pulling the `uuid` package for a
/// single call site — the random source is `Random.secure()` so the id
/// is suitable as a stable on-device identifier (collision probability
/// is the standard 2^-122).
String _uuidV4() {
  final Random rng = Random.secure();
  final List<int> bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0F) | 0x40;
  bytes[8] = (bytes[8] & 0x3F) | 0x80;
  String hex(int b) => b.toRadixString(16).padLeft(2, '0');
  final String h = bytes.map(hex).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
      '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}
