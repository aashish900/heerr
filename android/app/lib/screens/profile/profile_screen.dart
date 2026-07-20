import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/profile.dart';
import '../../models/profile_meta.dart';
import '../../providers/profiles/active_profile.dart';
import '../../providers/profiles/profile_avatar.dart';
import '../../providers/profiles/profile_meta.dart';
import '../../providers/profiles/profile_registry.dart';
import '../../providers/profiles/profile_stats.dart';
import '../../providers/app_version.dart';
import '../../router.dart';
import '../../services/backend_service.dart';
import '../../theme.dart';
import '../../widgets/heerr_logo.dart';
import '../../widgets/profile_avatar_ring.dart';

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
          const SizedBox(height: 28),
          const _SectionHeader('My Music'),
          const SizedBox(height: 8),
          _ProfileActionCard(
            key: const Key('profile-row-liked-songs'),
            icon: Icons.favorite_border,
            label: 'Liked Songs',
            // go, not push: /profile is itself an imperative push (Home
            // avatar), and go_router 14 throws a duplicated-page-key
            // assertion when push-ing a ShellRoute-nested route on top of
            // an imperatively-pushed non-shell route — on device the tap
            // silently did nothing. Matches the go-based rows below.
            onTap: () => context.go(Routes.libraryFavorites),
          ),
          _ProfileActionCard(
            key: const Key('profile-row-downloaded'),
            icon: Icons.download_outlined,
            label: 'Downloaded',
            onTap: () => context.go(Routes.downloads),
          ),
          _ProfileActionCard(
            key: const Key('profile-row-recently-played'),
            icon: Icons.history,
            label: 'Recently Played',
            // go, not push — same duplicated-page-key crash as Liked Songs.
            onTap: () => context.go(Routes.libraryRecentlyPlayed),
          ),
          _ProfileActionCard(
            key: const Key('profile-row-playlists'),
            icon: Icons.queue_music_outlined,
            label: 'Playlists',
            onTap: () => context.go(Routes.libraryPlaylistsTab),
          ),
          _ProfileActionCard(
            key: const Key('profile-row-podcasts'),
            icon: Icons.podcasts_outlined,
            label: 'Podcasts',
            // push, not go: podcasts routes are top-level (like /player),
            // not ShellRoute-nested, so there's no duplicated-page-key risk.
            onTap: () => context.push(Routes.podcastsSubscriptions),
          ),
          const SizedBox(height: 20),
          const _SectionHeader('Settings'),
          const SizedBox(height: 8),
          _ProfileActionCard(
            key: const Key('profile-row-settings'),
            icon: Icons.settings_outlined,
            iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
            label: 'Settings',
            onTap: () => context.go(Routes.settings),
          ),
          _ProfileActionCard(
            key: const Key('profile-row-help'),
            icon: Icons.help_outline,
            iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
            label: 'Help & Support',
            onTap: () => _showHelpDialog(context),
          ),
          _ProfileActionCard(
            key: const Key('profile-row-about'),
            icon: Icons.info_outline,
            iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
            label: 'About heerr',
            onTap: () => _showAboutDialog(context, ref),
          ),
          const SizedBox(height: 20),
          _LogOutButton(onConfirmed: () => _logOut(context, ref)),
        ],
      ),
    );
  }
}

void _showHelpDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: const Text('Help & Support'),
      content: const Text(
        'heerr is a self-hosted app — issues and questions go through the '
        'project repository. If playback or search stops working, first '
        'check that this device is connected to Tailscale and the backend '
        'server is reachable.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

void _showAboutDialog(BuildContext context, WidgetRef ref) {
  final String? version = ref.read(appVersionProvider).valueOrNull;
  showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          HeerrLogo(markSize: 28),
          SizedBox(width: 12),
          Text('About heerr'),
        ],
      ),
      content: Text(version == null ? 'Version unavailable' : 'Version $version'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

/// Best-effort remote token revoke, then local sign-out. The remote call
/// must never block the local sign-out — an unreachable backend is a
/// common reason someone wants to log out and try a different profile.
Future<void> _logOut(BuildContext context, WidgetRef ref) async {
  try {
    final BackendService service = await ref.read(backendServiceProvider.future);
    await service.logout();
  } catch (_) {
    // Best-effort — proceed to local sign-out regardless.
  }
  await ref.read(profileRegistryProvider.notifier).setActive(null);
  // The router's refreshListenable redirects to /login the instant the
  // active profile goes null — no manual navigation needed here.
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
            InkWell(
              key: const Key('profile-avatar'),
              customBorder: const CircleBorder(),
              onTap: () => context.push(Routes.profileEdit),
              child: ProfileAvatarRing(avatar: avatar, radius: 44),
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

/// "My Music" / "Settings" section label, per the mockup.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

/// One rounded, full-width row card — used for both the "My Music" section
/// (magenta outlined icons, per the mockup, the default) and the
/// "Settings" section (neutral grey/white icon tint).
class _ProfileActionCard extends StatelessWidget {
  const _ProfileActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = heerrMagenta,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: <Widget>[
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge,
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

/// Full-width outlined Log Out button (magenta icon + text + hairline
/// border, per the mockup). Confirms via an [AlertDialog] before invoking
/// [onConfirmed] — sign-out is disruptive enough to warrant a guard against
/// an accidental tap.
class _LogOutButton extends StatelessWidget {
  const _LogOutButton({required this.onConfirmed});

  final VoidCallback onConfirmed;

  Future<void> _confirm(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text("You'll need to sign back in to use heerr."),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed == true) onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const Key('profile-logout'),
        style: OutlinedButton.styleFrom(
          foregroundColor: heerrMagenta,
          side: const BorderSide(color: heerrMagenta, width: 1),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: () => _confirm(context),
        icon: const Icon(Icons.logout, color: heerrMagenta),
        label: const Text('Log Out'),
      ),
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
