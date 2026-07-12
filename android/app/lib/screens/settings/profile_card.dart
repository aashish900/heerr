import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/profile.dart';
import '../../providers/profiles/active_profile.dart';
import '../../providers/profiles/profile_avatar.dart';
import '../../router.dart';
import '../../widgets/profile_avatar_ring.dart';

/// Profile entry point at the top of the Settings tab (SETTINGSSCREEN.md
/// SE3) — a floating card with the gradient-ring avatar, display name, a
/// "Manage your profile" caption (no handle/premium badge — heerr is free,
/// per the redesign brief), and a chevron. Tapping pushes the full
/// `/profile` display screen. Renders nothing when signed out (mirrors the
/// router's redirect-to-/login state).
class ProfileCard extends ConsumerWidget {
  const ProfileCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Profile? profile = ref.watch(activeProfileProvider);
    if (profile == null) return const SizedBox.shrink();
    final File? avatar = ref.watch(profileAvatarProvider).valueOrNull;
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Material(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          key: const Key('settings-profile-card'),
          borderRadius: BorderRadius.circular(24),
          onTap: () => context.push(Routes.profile),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: <Widget>[
                ProfileAvatarRing(avatar: avatar, radius: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        profile.displayName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage your profile',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
