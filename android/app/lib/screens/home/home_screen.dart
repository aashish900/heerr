import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/recommended_track.dart';
import '../../models/subsonic/album.dart';
import '../../providers/home/home_providers.dart';
import '../../providers/library/library_search_query.dart';
import '../../providers/profiles/profile_avatar.dart';
import '../../providers/profiles/profile_meta.dart';
import '../../providers/recommendations.dart';
import '../../router.dart' show Routes;
import '../../theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_snackbar.dart';
import '../../widgets/heerr_logo.dart';
import '../../widgets/recommendations_refresh_button.dart';
import '../../widgets/home_grid_tile.dart';
import '../../widgets/home_recommendation_card.dart';
import '../../widgets/home_section.dart';
import '../../widgets/skeleton.dart';
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

/// Home screen: greeting + quick-access grid + horizontal sections.
///
/// Layout:
///   - AppBar greeting + Queue shortcut.
///   - Quick-access grid (2 cols × 3 rows) — recently-played; falls back
///     to recommendations when "recent" is empty.
///   - "Jump back in" — horizontal scroll of recently-played albums.
///   - "Most played" — horizontal scroll of frequent albums.
///   - "Picked for you" / "Discover" lands in O4.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // #38 — the recommendations feed is keep-alive; refresh it when stale
    // (30 min TTL) on every Home visit. No-ops while fresh or when a manual
    // "Find similar" seed is active. Post-frame so we don't mutate provider
    // state mid-build (same pattern as the Settings health check).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(recommendationsProvider.notifier).refreshIfStale();
    });
  }

  Future<void> _refresh(WidgetRef ref) async {
    // Invalidate each Home provider so the next read re-fetches.
    // `recommendationsProvider` is the upstream of `homeRecommendations` —
    // invalidating it propagates through the wrapper.
    ref.invalidate(homeRecentProvider);
    ref.invalidate(homeMostPlayedProvider);
    ref.invalidate(homeRandomSongsProvider);
    ref.invalidate(homeRecommendationsProvider);
    // Wait for at least one provider to settle so the spinner stays up
    // long enough to confirm the action took.
    await ref.read(homeRecentProvider.future).catchError((_) => const <Album>[]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Redesign task 1: the AppBar carries the brand mark; the greeting
        // lives in the body (_GreetingBlock) per the mockup.
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
      _invalidateAll();
    });
  }

  void _cancelAutoRetry({bool resetCount = false}) {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (resetCount) setState(() => _autoRetryCount = 0);
  }

  void _invalidateAll() {
    ref.invalidate(homeRecentProvider);
    ref.invalidate(homeMostPlayedProvider);
    ref.invalidate(homeRandomSongsProvider);
    ref.invalidate(homeRecommendationsProvider);
  }

  void _manualRetry() {
    _cancelAutoRetry(resetCount: true);
    _invalidateAll();
  }

  @override
  Widget build(BuildContext context) {
    // Use homeRecentProvider as the canonical network signal. When it
    // enters error state, schedule the auto-retry timer. When it enters
    // loading or data, cancel (data also resets the counter).
    ref.listen<AsyncValue<List<Album>>>(
      homeRecentProvider,
      (_, AsyncValue<List<Album>> next) {
        if (next.hasError) {
          _scheduleAutoRetry();
        } else {
          _cancelAutoRetry(resetCount: next.hasValue);
        }
      },
    );

    final AsyncValue<List<Album>> recent = ref.watch(homeRecentProvider);
    final AsyncValue<List<Album>> mostPlayed = ref.watch(homeMostPlayedProvider);
    final AsyncValue<HomeRecommendations> recs =
        ref.watch(homeRecommendationsProvider);

    final bool allFailed =
        recent.hasError && mostPlayed.hasError && recs.hasError;

    if (allFailed) {
      return _NetworkErrorBody(
        autoRetrying: _autoRetryCount < _kMaxAutoRetries,
        onRetry: _manualRetry,
      );
    }

    return ListView(
      // AlwaysScrollable so the RefreshIndicator works even when content
      // doesn't fill the viewport (e.g. on the full-empty home state).
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: const <Widget>[
        _HomeSearchBar(),
        _GreetingBlock(),
        ContinueListeningCard(),
        QuickAccessRow(),
        RecentlyAddedSection(),
        _QuickAccessGrid(),
        _JumpBackInSection(),
        _MostPlayedSection(),
        _RecommendationsSection(),
      ],
    );
  }
}

/// Shown when all Home providers fail simultaneously (e.g. Tailscale off).
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

class _QuickAccessGrid extends ConsumerWidget {
  const _QuickAccessGrid();

  static const int _kGridCount = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Album>> recent = ref.watch(homeRecentProvider);
    return recent.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: SkeletonBox(width: double.infinity, height: 200),
      ),
      error: (Object e, _) => const SizedBox.shrink(),
      data: (List<Album> albums) {
        if (albums.isNotEmpty) {
          return _buildGrid(context, _albumsToGridItems(context, albums));
        }
        // Fallback: when nothing has been played yet, fill the grid with
        // recommendations so the slot doesn't sit empty.
        return const _RecommendationGridFallback(maxItems: _kGridCount);
      },
    );
  }

  static Widget _buildGrid(BuildContext context, List<HomeGridTile> tiles) {
    final List<HomeGridTile> capped = tiles.take(_kGridCount).toList();
    if (capped.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 3.2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        children: capped,
      ),
    );
  }

  static List<HomeGridTile> _albumsToGridItems(
      BuildContext context, List<Album> albums) {
    return albums
        .map((Album a) => HomeGridTile(
              title: a.name,
              coverArtId: a.coverArt,
              onTap: () => context.push(Routes.libraryAlbum(a.id)),
            ))
        .toList();
  }
}

class _RecommendationGridFallback extends ConsumerWidget {
  const _RecommendationGridFallback({required this.maxItems});

  final int maxItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<HomeRecommendations> recs =
        ref.watch(homeRecommendationsProvider);
    return recs.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: SkeletonBox(width: double.infinity, height: 200),
      ),
      error: (Object e, _) => const SizedBox.shrink(),
      data: (HomeRecommendations data) {
        if (data.tracks.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: EmptyState(
              icon: Icons.library_music_outlined,
              title: 'Nothing here yet',
              subtitle:
                  'Play some music or download a track to start filling out '
                  'your home.',
            ),
          );
        }
        final List<HomeGridTile> tiles = data.tracks
            .take(maxItems)
            .map((RecommendedTrack t) => HomeGridTile(
                  title: t.title,
                  coverArtId: null,
                  // In O3 fallback we don't have an album/playlist route for
                  // a track-level row. The tap is a no-op here — O4 surfaces
                  // recommendations in the proper card section where the
                  // Play/Download branching lives.
                  onTap: () {},
                ))
            .toList();
        return _QuickAccessGrid._buildGrid(context, tiles);
      },
    );
  }
}

class _JumpBackInSection extends ConsumerWidget {
  const _JumpBackInSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Album>> recent = ref.watch(homeRecentProvider);
    return recent.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: SkeletonBox(width: double.infinity, height: 180),
      ),
      error: (Object e, _) => const SizedBox.shrink(),
      data: (List<Album> albums) {
        if (albums.isEmpty) return const SizedBox.shrink();
        return HomeSection(
          title: 'Jump back in',
          items: albums
              .map((Album a) => HomeSectionItem(
                    title: a.name,
                    subtitle: a.artist,
                    coverArtId: a.coverArt,
                    onTap: () => context.push(Routes.libraryAlbum(a.id)),
                  ))
              .toList(),
        );
      },
    );
  }
}

/// Horizontal section dedicated to recommendations. Uses
/// [HomeRecommendationCard] (taller card with action button) rather than
/// the album-cover `HomeSection`. Header text switches between "Picked
/// for you" and "Discover" depending on whether the section is showing
/// real recommendations or the random-songs fallback.
class _RecommendationsSection extends ConsumerWidget {
  const _RecommendationsSection();

  static const double _kCardWidth = 160;
  static const double _kCardSpacing = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<HomeRecommendations> async =
        ref.watch(homeRecommendationsProvider);
    // #38: a failed refresh keeps the previous cards on screen (skipError
    // below) — surface the failure once per error class instead.
    ref.listen(homeRecommendationsProvider,
        (AsyncValue<HomeRecommendations>? prev,
                AsyncValue<HomeRecommendations> next) =>
            reactToApiError(context, prev, next));
    return async.when(
      // #38: on refresh, keep showing the previous picks (dimmed via the
      // AnimatedOpacity below) instead of dropping to the skeleton. The
      // skeleton still renders on first load (no previous value).
      skipLoadingOnReload: true,
      skipError: true,
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: SkeletonBox(width: double.infinity, height: 280),
      ),
      error: (Object e, _) => const SizedBox.shrink(),
      data: (HomeRecommendations data) {
        if (data.tracks.isEmpty) return const SizedBox.shrink();
        final String header = data.isFallback ? 'Discover' : 'Picked for you';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        header,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    // #38 — explicit "fetch new recommendations". Re-samples
                    // the seed collection so successive taps differ. On the
                    // Discover fallback, also reshuffle the random songs the
                    // section is actually showing.
                    RecommendationsRefreshButton(
                      key: const Key('home-recs-refresh'),
                      onBeforeRefresh: data.isFallback
                          ? () => ref.invalidate(homeRandomSongsProvider)
                          : null,
                    ),
                  ],
                ),
              ),
              // #38: dim the previous picks while a refresh is in flight —
              // paired with skipLoadingOnReload above, so the cards stay
              // visible (no skeleton flash) and the spin/dim signal "new
              // ones coming".
              AnimatedOpacity(
                opacity: async.isLoading ? 0.4 : 1,
                duration: const Duration(milliseconds: 200),
                child: SizedBox(
                  height: 280,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: data.tracks.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: _kCardSpacing),
                    itemBuilder: (BuildContext c, int i) =>
                        HomeRecommendationCard(
                      track: data.tracks[i],
                      width: _kCardWidth,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MostPlayedSection extends ConsumerWidget {
  const _MostPlayedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Album>> frequent =
        ref.watch(homeMostPlayedProvider);
    return frequent.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: SkeletonBox(width: double.infinity, height: 180),
      ),
      error: (Object e, _) => const SizedBox.shrink(),
      data: (List<Album> albums) {
        if (albums.isEmpty) return const SizedBox.shrink();
        return HomeSection(
          title: 'Most played',
          items: albums
              .map((Album a) => HomeSectionItem(
                    title: a.name,
                    subtitle: a.artist,
                    coverArtId: a.coverArt,
                    onTap: () => context.push(Routes.libraryAlbum(a.id)),
                  ))
              .toList(),
        );
      },
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
        borderRadius: BorderRadius.circular(28),
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
