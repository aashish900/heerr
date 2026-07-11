import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/profile.dart';
import '../../models/profile_meta.dart';
import '../../providers/profiles/active_profile.dart';
import '../../providers/profiles/profile_avatar.dart';
import '../../providers/profiles/profile_meta.dart';
import '../../providers/profiles/profile_stats.dart';
import '../../router.dart';
import '../../theme.dart';

/// Display-first profile page (Phase Z redesign). Shows the gradient-ring
/// avatar with an edit-pencil badge, the display name, `@navidromeUsername`
/// handle, and the bio — editing lives behind the pencil at
/// `/profile/edit` ([ProfileEditScreen]).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Profile? profile = ref.watch(activeProfileProvider);
    final File? avatar = ref.watch(profileAvatarProvider).valueOrNull;
    final ProfileMeta meta =
        ref.watch(profileMetaNotifierProvider).valueOrNull ??
            const ProfileMeta();

    // Signed-out: the router redirect rewrites to /login; render nothing
    // for the frame in between.
    if (profile == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _ProfileHeader(profile: profile, avatar: avatar, meta: meta),
          const SizedBox(height: 24),
          const _StatsRow(),
        ],
      ),
    );
  }
}

/// Avatar (gradient ring + pencil badge) beside name / handle / bio.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.avatar,
    required this.meta,
  });

  final Profile profile;
  final File? avatar;
  final ProfileMeta meta;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Color grey = Theme.of(context).colorScheme.onSurfaceVariant;
    final String? bio = meta.bio;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            // Same ring stack as the edit form: gradient circle → thin
            // black gap → the photo.
            InkWell(
              key: const Key('profile-avatar'),
              customBorder: const CircleBorder(),
              onTap: () => context.push(Routes.profileEdit),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  gradient: heerrGradient,
                  shape: BoxShape.circle,
                ),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: heerrBlack,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 44,
                    foregroundImage:
                        avatar != null ? FileImage(avatar!) : null,
                    child: avatar == null
                        ? const Icon(Icons.person_outline, size: 44)
                        : null,
                  ),
                ),
              ),
            ),
            // Edit-pencil badge overlapping the avatar's bottom-right,
            // per the mockup.
            Positioned(
              right: -2,
              bottom: -2,
              child: InkWell(
                key: const Key('profile-edit-badge'),
                customBorder: const CircleBorder(),
                onTap: () => context.push(Routes.profileEdit),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: heerrBlack,
                    shape: BoxShape.circle,
                    border: Border.all(color: heerrMagenta, width: 1.5),
                  ),
                  child: const Icon(Icons.edit_outlined, size: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                profile.displayName,
                key: const Key('profile-display-name'),
                style: text.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '@${profile.navidromeUsername}',
                key: const Key('profile-handle'),
                style: text.bodyMedium?.copyWith(color: grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (bio != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  bio,
                  key: const Key('profile-bio'),
                  style: text.bodyMedium?.copyWith(color: grey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Four-column stats row: Playlists / Songs / Albums / Artists, separated
/// by thin dividers. Stats are nice-to-have, never worth an error surface —
/// same posture as `_AppVersionTile` in settings_screen.dart: skeleton dash
/// while loading or on error, no snackbar/retry affordance.
class _StatsRow extends ConsumerWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ProfileStats? stats = ref.watch(profileStatsProvider).valueOrNull;

    return Row(
      children: <Widget>[
        Expanded(
          child: _StatColumn(
            key: const Key('profile-stat-playlists'),
            count: stats?.playlists,
            label: 'Playlists',
          ),
        ),
        const _StatDivider(),
        Expanded(
          child: _StatColumn(
            key: const Key('profile-stat-songs'),
            count: stats?.songs,
            label: 'Songs',
          ),
        ),
        const _StatDivider(),
        Expanded(
          child: _StatColumn(
            key: const Key('profile-stat-albums'),
            count: stats?.albums,
            label: 'Albums',
          ),
        ),
        const _StatDivider(),
        Expanded(
          child: _StatColumn(
            key: const Key('profile-stat-artists'),
            count: stats?.artists,
            label: 'Artists',
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({super.key, required this.count, required this.label});

  final int? count;
  final String label;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Color grey = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      children: <Widget>[
        Text(
          count == null ? '—' : formatStatCount(count!),
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(label, style: text.bodySmall?.copyWith(color: grey)),
      ],
    );
  }
}
