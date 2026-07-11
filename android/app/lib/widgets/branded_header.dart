import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/profiles/profile_avatar.dart';
import '../providers/profiles/profile_meta.dart';
import '../router.dart' show Routes;
import 'heerr_logo.dart';
import 'profile_avatar_ring.dart';

/// Time-of-day greeting helper. Visible for tests.
/// - 5..11  → "Good morning"
/// - 12..17 → "Good afternoon"
/// - else   → "Good evening"
String greetingForHour(int hour) {
  if (hour >= 5 && hour <= 11) return 'Good morning';
  if (hour >= 12 && hour <= 17) return 'Good afternoon';
  return 'Good evening';
}

/// Shared branded AppBar for top-level screens (Home, Library — X1,
/// LIBRARYSCREEN.md). Title is either the full logo (mark + wordmark, Home)
/// or the mark + a compact two-line greeting (Library). Trailing actions are
/// always the Queue shortcut + profile avatar; screen-specific actions (e.g.
/// Library's search) slot in before them via [actions].
class BrandedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandedAppBar({
    this.compactGreeting = false,
    this.actions = const <Widget>[],
    super.key,
  });

  /// When true the title renders the logo mark + small greeting column
  /// instead of the mark + wordmark row.
  final bool compactGreeting;

  /// Extra actions inserted before the shared Queue + avatar actions.
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: false,
      title: compactGreeting ? const _CompactGreeting() : const HeerrLogo(),
      actions: <Widget>[
        ...actions,
        IconButton(
          icon: const Icon(Icons.queue_music_outlined),
          tooltip: 'Queue',
          onPressed: () => context.go(Routes.queue),
        ),
        const ProfileAvatarButton(),
      ],
    );
  }
}

/// Logo mark + two-line compact greeting ("Good evening," over the nickname
/// + wave). Without a nickname the greeting renders as a single line, no
/// emoji — same nickname contract as [GreetingBlock].
class _CompactGreeting extends ConsumerWidget {
  const _CompactGreeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? nickname =
        ref.watch(profileMetaNotifierProvider).valueOrNull?.nickname;
    final String greeting = greetingForHour(DateTime.now().hour);
    final TextTheme tt = Theme.of(context).textTheme;
    final ColorScheme cs = Theme.of(context).colorScheme;

    final TextStyle? boldStyle =
        tt.titleMedium?.copyWith(fontWeight: FontWeight.w700);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const HeerrLogo(showWordmark: false),
        const SizedBox(width: 10),
        nickname == null
            ? Text(greeting, style: boldStyle)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '$greeting,',
                    style:
                        tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Text('$nickname \u{1F44B}', style: boldStyle),
                ],
              ),
      ],
    );
  }
}

/// Profile entry point (#37): a small circular avatar in the AppBar — the
/// profile picture when one is set, a person glyph otherwise. Taps push the
/// full-screen `/profile` page. Extracted from Home at X1 so Library shares
/// it; the key keeps its historical Home name for test continuity.
class ProfileAvatarButton extends ConsumerWidget {
  const ProfileAvatarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final File? avatar = ref.watch(profileAvatarProvider).valueOrNull;
    return IconButton(
      key: const Key('home-profile-avatar'),
      tooltip: 'Profile',
      onPressed: () => context.push(Routes.profile),
      // Gradient ring around the avatar — the brand accent, consistent with
      // the full Profile screen's avatar treatment (shared ProfileAvatarRing).
      icon: ProfileAvatarRing(
        avatar: avatar,
        radius: 14,
        ringPadding: 2,
        gapPadding: 1.5,
      ),
    );
  }
}

/// Two-line greeting block for the Home body (mockup zone 3).
/// Line 1: time-of-day greeting in small grey. Line 2: the profile nickname
/// large + a waving-hand emoji (UI copy from the mockup — the no-emoji rule
/// covers code/commits, not user-facing strings). Without a nickname the
/// greeting itself renders as the single large line, no emoji.
class GreetingBlock extends ConsumerWidget {
  const GreetingBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? nickname =
        ref.watch(profileMetaNotifierProvider).valueOrNull?.nickname;
    final String greeting = greetingForHour(DateTime.now().hour);
    final TextTheme tt = Theme.of(context).textTheme;
    final ColorScheme cs = Theme.of(context).colorScheme;

    final TextStyle? bigStyle =
        tt.headlineMedium?.copyWith(fontWeight: FontWeight.w800);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: nickname == null
          ? Text(greeting, style: bigStyle)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$greeting,',
                  style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
                Text('$nickname \u{1F44B}', style: bigStyle),
              ],
            ),
    );
  }
}
