import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/subsonic/album.dart';
import '../../player/player_provider.dart';
import '../../providers/home/home_providers.dart';
import '../../providers/library/library_search_query.dart';
import '../../providers/profiles/profile_avatar.dart';
import '../../providers/profiles/profile_meta.dart';
import '../../router.dart' show Routes;
import '../../theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/heerr_logo.dart';
import 'continue_listening_card.dart';
import 'quick_access_row.dart';
import 'recently_added_section.dart';

/// Time-of-day greeting helper. Visible for tests.
/// - 5..11  → "Good morning"
/// - 12..17 → "Good afternoon"
/// - else   → "Good evening"
String greetingForHour(int hour) {
  if (hour >= 5 && hour <= 11) return 'Good morning';
  if (hour >= 12 && hour <= 17) return 'Good afternoon';
  return 'Good evening';
}

/// Home screen — 2026-07 redesign (docs/HOMESCREEN.md).
///
/// Layout (top → bottom):
///   - AppBar: brand logo + Queue shortcut + profile avatar.
///   - Search affordance (chokepoint into Library search).
///   - Greeting block (nickname-aware).
///   - "Continue Listening" hero card (player-driven; hidden when idle).
///   - Quick Access shortcut row (static 4 cards).
///   - "Recently Added" vertical list (newest albums) — or the empty-state
///     when the library is empty and nothing is queued.
///
/// The pre-redesign sections (recently-played grid, "Jump back in",
/// "Most played", "Picked for you") were removed — DECISIONLOG 2026-07-11.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    // homeNewest is Home's only network-bound section now; the hero card is
    // player-local and Quick Access is static/disk-local.
    ref.invalidate(homeNewestProvider);
    // Wait for the fetch to settle so the spinner stays up long enough to
    // confirm the action took.
    await ref
        .read(homeNewestProvider.future)
        .catchError((_) => const <Album>[]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const HeerrLogo(),
        centerTitle: false,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.queue_music_outlined),
            tooltip: 'Queue',
            onPressed: () => context.go(Routes.queue),
          ),
          const _ProfileAvatarButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: const _HomeBody(),
      ),
    );
  }
}

/// Profile entry point (#37): a small circular avatar in the Home AppBar —
/// the profile picture when one is set, a person glyph otherwise. Taps push
/// the full-screen `/profile` page.
class _ProfileAvatarButton extends ConsumerWidget {
  const _ProfileAvatarButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final File? avatar = ref.watch(profileAvatarProvider).valueOrNull;
    return IconButton(
      key: const Key('home-profile-avatar'),
      tooltip: 'Profile',
      onPressed: () => context.push(Routes.profile),
      // Gradient ring around the avatar — the brand accent, consistent with
      // the full Profile screen's avatar treatment.
      icon: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          gradient: heerrGradient,
          shape: BoxShape.circle,
        ),
        child: Container(
          padding: const EdgeInsets.all(1.5),
          decoration: const BoxDecoration(
            color: heerrBlack,
            shape: BoxShape.circle,
          ),
          child: CircleAvatar(
            radius: 14,
            foregroundImage: avatar != null ? FileImage(avatar) : null,
            child: avatar == null
                ? const Icon(Icons.person_outline, size: 16)
                : null,
          ),
        ),
      ),
    );
  }
}

/// Two-line greeting block under the search bar (mockup zone 3).
/// Line 1: time-of-day greeting in small grey. Line 2: the profile nickname
/// large + a waving-hand emoji (UI copy from the mockup — the no-emoji rule
/// covers code/commits, not user-facing strings). Without a nickname the
/// greeting itself renders as the single large line, no emoji.
class _GreetingBlock extends ConsumerWidget {
  const _GreetingBlock();

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

class _HomeBody extends ConsumerStatefulWidget {
  const _HomeBody();

  @override
  ConsumerState<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends ConsumerState<_HomeBody> {
  // Auto-retry: fire every 5 s, up to 6 attempts (30 s ceiling).
  // After exhaustion the user must tap Retry manually.
  static const int _kMaxAutoRetries = 6;
  static const Duration _kAutoRetryInterval = Duration(seconds: 5);

  int _autoRetryCount = 0;
  Timer? _retryTimer;

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _scheduleAutoRetry() {
    if (_retryTimer?.isActive ?? false) return;
    if (_autoRetryCount >= _kMaxAutoRetries) return;
    _retryTimer = Timer(_kAutoRetryInterval, () {
      if (!mounted) return;
      setState(() => _autoRetryCount++);
      ref.invalidate(homeNewestProvider);
    });
  }

  void _cancelAutoRetry({bool resetCount = false}) {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (resetCount) setState(() => _autoRetryCount = 0);
  }

  void _manualRetry() {
    _cancelAutoRetry(resetCount: true);
    ref.invalidate(homeNewestProvider);
  }

  @override
  Widget build(BuildContext context) {
    // homeNewest is the canonical network signal (the only network-bound
    // Home provider post-redesign). Error → schedule auto-retry; loading or
    // data → cancel (data also resets the counter).
    ref.listen<AsyncValue<List<Album>>>(
      homeNewestProvider,
      (_, AsyncValue<List<Album>> next) {
        if (next.hasError) {
          _scheduleAutoRetry();
        } else {
          _cancelAutoRetry(resetCount: next.hasValue);
        }
      },
    );

    final AsyncValue<List<Album>> newest = ref.watch(homeNewestProvider);

    if (newest.hasError && !newest.hasValue) {
      return _NetworkErrorBody(
        autoRetrying: _autoRetryCount < _kMaxAutoRetries,
        onRetry: _manualRetry,
      );
    }

    // Full-empty home: nothing in the library AND nothing queued in the
    // player → swap the Recently Added slot for the onboarding empty-state.
    final bool libraryEmpty =
        newest.hasValue && (newest.valueOrNull?.isEmpty ?? false);
    final bool playerIdle =
        ref.watch(playerSnapshotProvider).valueOrNull?.item == null;

    return ListView(
      // AlwaysScrollable so the RefreshIndicator works even when content
      // doesn't fill the viewport (e.g. on the full-empty home state).
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: <Widget>[
        const _HomeSearchBar(),
        const _GreetingBlock(),
        const ContinueListeningCard(),
        const QuickAccessRow(),
        if (libraryEmpty && playerIdle)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: EmptyState(
              icon: Icons.library_music_outlined,
              title: 'Nothing here yet',
              subtitle:
                  'Play some music or download a track to start filling out '
                  'your home.',
            ),
          )
        else
          const RecentlyAddedSection(),
      ],
    );
  }
}

/// Shown when the Home network provider fails (e.g. Tailscale off).
/// Wrapped in a scrollable list so the parent [RefreshIndicator] still
/// responds to pull-down gestures alongside the manual Retry button.
class _NetworkErrorBody extends StatelessWidget {
  const _NetworkErrorBody({
    required this.autoRetrying,
    required this.onRetry,
  });

  final bool autoRetrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.wifi_off_outlined,
                      size: 56, color: cs.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(
                    "Can't reach server",
                    style: tt.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check that Tailscale is connected.',
                    style: tt.bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (autoRetrying)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Retrying automatically…',
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  FilledButton.icon(
                    key: const Key('home-retry-button'),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tappable search affordance at the top of Home. Tapping it requests
/// the Library tab to auto-enter search mode on next mount, then
/// navigates to /library — search lives on a single chokepoint
/// (Library's combined-search field), so this surface is presentation
/// only and not a duplicate input.
class _HomeSearchBar extends ConsumerWidget {
  const _HomeSearchBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: colors.surfaceContainerHighest,
        // Mockup: squarish pill with gently curved corners, not a stadium.
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            ref.read(librarySearchAutoFocusProvider.notifier).request();
            ref.read(librarySearchQueryProvider.notifier).clear();
            context.go(Routes.library);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: <Widget>[
                Icon(Icons.search, color: colors.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Search your library + YouTube Music',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
