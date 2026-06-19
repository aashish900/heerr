import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/profile.dart';
import 'profiles/active_profile.dart';

part 'server_creds.g.dart';

/// The Navidrome credential slice of the active [Profile].
///
/// A6: extracted out of the former 12-field `SettingsValue` so that consumers
/// needing only per-server creds (the offline serverKey chokepoints, the
/// streaming + Now-Playing-persistence paths, owner-check providers) rebuild
/// only on a profile switch — not on every offline-preference toggle. Field
/// names match the old `SettingsValue` so the offline path helpers' bodies are
/// unchanged; only the parameter *type* moved.
///
/// All fields are nullable: a fresh install has no active profile yet, and the
/// offline helpers already treat null/empty creds as a no-op (return `null`
/// from `OfflinePaths.serverRoot`, etc.).
typedef ServerCreds = ({
  String? navidromeBaseUrl,
  String? navidromeUsername,
  String? navidromePassword,
});

/// Re-slice of [activeProfileProvider]. Synchronous — `activeProfileProvider`
/// is itself synchronous (it reads the already-loaded registry state).
@riverpod
ServerCreds serverCreds(ServerCredsRef ref) {
  final Profile? p = ref.watch(activeProfileProvider);
  return (
    navidromeBaseUrl: p?.navidromeBaseUrl,
    navidromeUsername: p?.navidromeUsername,
    navidromePassword: p?.navidromePassword,
  );
}
