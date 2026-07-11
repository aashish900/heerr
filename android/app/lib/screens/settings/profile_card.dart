import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/profile.dart';
import '../../providers/profiles/active_profile.dart';
import '../../providers/profiles/profile_avatar.dart';
import '../../router.dart';
import '../../widgets/profile_avatar_ring.dart';

/// Compact profile entry point at the top of the Settings tab (Phase Z
/// redesign) — small gradient-ring avatar, display name, `@handle`, and a
/// chevron. Tapping pushes the full `/profile` display screen. Renders
/// nothing when signed out (mirrors the router's redirect-to-/login state).
class ProfileCard extends ConsumerWidget {
  const ProfileCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Profile? profile = ref.watch(activeProfileProvider);
    if (profile == null) return const SizedBox.shrink();
    final File? avatar = ref.watch(profileAvatarProvider).valueOrNull;

    return ListTile(
      key: const Key('settings-profile-card'),
      leading: ProfileAvatarRing(avatar: avatar, radius: 18),
      title: Text(
        profile.displayName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('@${profile.navidromeUsername}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(Routes.profile),
    );
  }
}
