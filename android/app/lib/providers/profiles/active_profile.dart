import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/profile.dart';
import 'profile_registry.dart';

part 'active_profile.g.dart';

/// The currently-active [Profile], derived from [profileRegistryProvider].
///
/// Returns `null` when no profile is active (fresh install pre-login, or
/// after the user removed the active profile from Settings). Watchers
/// should treat `null` as "redirect to /login" — the router's
/// first-launch redirect (S5) handles that for routed navigation.
///
/// `Settings`-scoped fields that aren't per-profile (offline toggles,
/// sleep-timer defaults) continue to live in `settingsProvider`. Only
/// the per-server credential set moves under this provider.
@Riverpod(keepAlive: true)
Profile? activeProfile(ActiveProfileRef ref) {
  final AsyncValue<ProfileRegistryState> async =
      ref.watch(profileRegistryProvider);
  final ProfileRegistryState? state = async.valueOrNull;
  if (state == null) return null;
  final String? activeId = state.activeId;
  if (activeId == null) return null;
  for (final Profile p in state.profiles) {
    if (p.id == activeId) return p;
  }
  return null;
}
