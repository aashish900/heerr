import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:heerr/models/profile.dart';
import 'package:heerr/providers/profiles/active_profile.dart';

/// Shared test plumbing for the A1/A5 credential + prefs split.
///
/// A1 made the active [Profile] the sole source of per-server credentials,
/// and A5 moved the offline prefs into plain `shared_preferences`. As a
/// result, any test that builds `settingsProvider` must (a) be able to read
/// the offline prefs without crashing on the platform channel, and (b)
/// supply credentials via the active profile rather than legacy secure-storage
/// keys.

/// Make the default `SharedPrefsStorage` resolve to an empty in-memory mock
/// so `settingsProvider` can build in unit/widget tests. Offline prefs read
/// back as their defaults. Call once at the top of `main()`.
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

/// `activeProfileProvider` override that makes `settingsProvider` resolve the
/// given per-server credentials (A1). Pass-through to [testProfile].
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
