import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/profile.dart';
import '../../providers/profiles/profile_registry.dart';
import '../../router.dart';

/// Profiles management section shown in [SettingsScreen]. Lists every
/// [Profile] in the registry with its display name + Navidrome username
/// + relative `lastUsedAt`. The currently-active profile gets a check
/// icon; tapping any non-active row prompts to switch.
///
/// Implements the S9 contract:
///   - **Add profile** — pushes the existing `/login` screen.
///   - **Switch** — confirmation dialog → `setActive(id)` → router
///     re-routes to Home so stale data isn't visible.
///   - **Remove** — confirmation dialog (warning about offline downloads
///     becoming inaccessible until next login). Removing the active
///     profile leaves the registry without an active pointer; the router
///     redirect (S5) takes the user back to `/login` on the next push.
class ProfilesSection extends ConsumerWidget {
  const ProfilesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ProfileRegistryState> async =
        ref.watch(profileRegistryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'Profiles',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        async.when(
          loading: () => const ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Loading profiles…'),
          ),
          error: (Object e, _) => ListTile(
            leading: const Icon(Icons.error_outline),
            title: const Text('Could not load profiles'),
            subtitle: Text('$e'),
          ),
          data: (ProfileRegistryState state) => Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final Profile p in state.profiles)
                _ProfileRow(
                  profile: p,
                  isActive: p.id == state.activeId,
                ),
              if (state.profiles.isEmpty)
                const ListTile(
                  leading: Icon(Icons.person_off_outlined),
                  title: Text('No profiles yet'),
                  subtitle: Text(
                    'Tap "Add profile" to sign in for the first time.',
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.person_add_outlined),
                title: const Text('Add profile'),
                onTap: () => context.push(Routes.login),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileRow extends ConsumerWidget {
  const _ProfileRow({required this.profile, required this.isActive});

  final Profile profile;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.person_outline),
      title: Text(profile.displayName),
      subtitle: Text(
        '${profile.navidromeUsername} • last used '
        '${_formatRelative(profile.lastUsedAt)}',
      ),
      trailing: PopupMenuButton<_RowAction>(
        onSelected: (_RowAction a) => _onAction(context, ref, a),
        itemBuilder: (BuildContext _) => <PopupMenuEntry<_RowAction>>[
          if (!isActive)
            const PopupMenuItem<_RowAction>(
              value: _RowAction.switchTo,
              child: Text('Switch to this profile'),
            ),
          const PopupMenuItem<_RowAction>(
            value: _RowAction.remove,
            child: Text('Remove'),
          ),
        ],
      ),
      onTap: isActive ? null : () => _switchTo(context, ref),
      // Visual marker for active row.
      selected: isActive,
      selectedTileColor:
          Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
      iconColor:
          isActive ? Theme.of(context).colorScheme.primary : null,
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _RowAction action,
  ) async {
    switch (action) {
      case _RowAction.switchTo:
        await _switchTo(context, ref);
      case _RowAction.remove:
        await _remove(context, ref);
    }
  }

  Future<void> _switchTo(BuildContext context, WidgetRef ref) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Switch profile?'),
        content: Text(
          'heerr will reload as ${profile.displayName}. Offline downloads '
          'and Now Playing for the current profile stay on disk.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Switch'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(profileRegistryProvider.notifier).setActive(profile.id);
    await ref
        .read(profileRegistryProvider.notifier)
        .bumpLastUsed(profile.id);
    if (!context.mounted) return;
    context.go(Routes.home);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Remove ${profile.displayName}?'),
        content: const Text(
          "Offline downloads for this profile remain on disk but will be "
          'inaccessible until you sign in again. The bearer token is '
          'erased from the device.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(profileRegistryProvider.notifier).removeProfile(profile.id);
    if (!context.mounted) return;
    // If we removed the active profile, the router redirect will land on
    // /login on the next navigation; nudge it explicitly so the user
    // sees the right screen immediately.
    final ProfileRegistryState? after =
        ref.read(profileRegistryProvider).valueOrNull;
    if (after?.activeId == null) {
      context.go(Routes.login);
    }
  }
}

enum _RowAction { switchTo, remove }

String _formatRelative(DateTime when) {
  final DateTime now = DateTime.now().toUtc();
  final Duration diff = now.difference(when.toUtc());
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 30) return '${diff.inDays} d ago';
  return '${(diff.inDays / 30).floor()} mo ago';
}
