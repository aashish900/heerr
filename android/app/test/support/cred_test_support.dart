import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:heerr/models/profile.dart';
import 'package:heerr/providers/profiles/active_profile.dart';
import 'package:heerr/providers/server_creds.dart';

/// Shared test plumbing for the A1/A5/A6 credential + prefs split.
///
/// A1 made the active [Profile] the sole source of per-server credentials,
/// A5 moved the offline prefs into plain `shared_preferences`, and A6 split
/// the former `SettingsValue` into [ServerCreds] (a re-slice of the active
/// profile) + the standalone `OfflineSettings` provider. As a result, any
/// test that needs creds (a) overrides `activeProfileProvider` — which feeds
/// `serverCredsProvider` transitively — and (b) calls [initPrefsMock] so the
/// offline prefs read back without a platform channel.

/// Make the default `SharedPrefsStorage` resolve to an empty in-memory mock
/// so `offlineSettingsProvider` can build in unit/widget tests. Offline prefs
/// read back as their defaults. Call once at the top of `main()`.
void initPrefsMock() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});
}

/// A [Profile] carrying the given identity. Defaults match the historical
/// `(http://navi:4533, me)` pair so existing serverKey-derived expectations
/// stay stable.
Profile testProfile({
  String id = 'p1',
  String heerrBaseUrl = 'http://x:8000/api/v1',
  String heerrBearerToken = 'tok',
  String navidromeBaseUrl = 'http://navi:4533',
  String navidromeUsername = 'me',
  String navidromePassword = 'pw',
}) {
  final DateTime t = DateTime.utc(2026, 6, 19);
  return Profile(
    id: id,
    displayName: navidromeUsername,
    heerrBaseUrl: heerrBaseUrl,
    heerrBearerToken: heerrBearerToken,
    navidromeBaseUrl: navidromeBaseUrl,
    navidromeUsername: navidromeUsername,
    navidromePassword: navidromePassword,
    createdAt: t,
    lastUsedAt: t,
  );
}

/// A [ServerCreds] record (A6) carrying the Navidrome credential slice. Use
/// where a helper takes a `ServerCreds` directly (offline path / manifest /
/// downloader tests). Defaults match [testProfile].
ServerCreds testCreds({
  String? navidromeBaseUrl = 'http://navi:4533',
  String? navidromeUsername = 'me',
  String? navidromePassword = 'pw',
}) {
  return (
    navidromeBaseUrl: navidromeBaseUrl,
    navidromeUsername: navidromeUsername,
    navidromePassword: navidromePassword,
  );
}

/// `activeProfileProvider` override that makes `serverCredsProvider` resolve
/// the given per-server credentials (A1/A6). Pass-through to [testProfile].
Override activeProfileOverride({
  String navidromeBaseUrl = 'http://navi:4533',
  String navidromeUsername = 'me',
  String navidromePassword = 'pw',
  String heerrBaseUrl = 'http://x:8000/api/v1',
  String heerrBearerToken = 'tok',
}) {
  return activeProfileProvider.overrideWithValue(
    testProfile(
      heerrBaseUrl: heerrBaseUrl,
      heerrBearerToken: heerrBearerToken,
      navidromeBaseUrl: navidromeBaseUrl,
      navidromeUsername: navidromeUsername,
      navidromePassword: navidromePassword,
    ),
  );
}
