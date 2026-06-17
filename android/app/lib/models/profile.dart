import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile.freezed.dart';
part 'profile.g.dart';

/// One on-device user profile for the multi-user (Phase S / v3.0.0) work.
///
/// A Profile bundles every per-server credential the app needs to talk to
/// a single `{heerr backend, Navidrome}` pair on behalf of one Navidrome
/// user. Identity is delegated to Navidrome via the backend's
/// `POST /api/v1/auth/login`; the password is stored on-device only
/// because the next login attempt needs to re-issue it to the backend.
///
/// Per-server isolation across offline downloads, library cache, queue
/// persistence, sleep timer and scrobble controller is keyed on
/// `serverKey = sha256(heerrBaseUrl + "|" + navidromeUsername).hex[0..16]`
/// — the same chokepoint introduced in L1. Profile-switch swaps the
/// active id; existing offline state for the previous profile is left on
/// disk untouched.
@freezed
class Profile with _$Profile {
  const factory Profile({
    required String id,
    required String displayName,
    required String heerrBaseUrl,
    required String heerrBearerToken,
    required String navidromeBaseUrl,
    required String navidromeUsername,
    required String navidromePassword,
    required DateTime createdAt,
    required DateTime lastUsedAt,
  }) = _Profile;

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);
}
