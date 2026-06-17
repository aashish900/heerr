import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/recommended_track.dart';
import '../../models/subsonic/album.dart';
import '../../providers/home/home_providers.dart';
import '../../providers/library/library_search_query.dart';
import '../../router.dart' show Routes;
import '../../widgets/empty_state.dart';
import '../../widgets/home_grid_tile.dart';
import '../../widgets/home_recommendation_card.dart';
import '../../widgets/home_section.dart';
import '../../widgets/skeleton.dart';

/// Time-of-day greeting helper. Visible for tests.
/// - 5..11  → "Good morning"
/// - 12..17 → "Good afternoon"
/// - else   → "Good evening"
String greetingForHour(int hour) {
  if (hour >= 5 && hour <= 11) return 'Good morning';
  if (hour >= 12 && hour <= 17) return 'Good afternoon';
  return 'Good evening';
}

/// Spotify-style Home: greeting + quick-access grid + horizontal sections.
///
/// Layout:
///   - AppBar greeting + Queue shortcut.
///   - Quick-access grid (2 cols × 3 rows) — recently-played; falls back
///     to recommendations when "recent" is empty.
///   - "Jump back in" — horizontal scroll of recently-played albums.
///   - "Most played" — horizontal scroll of frequent albums.
///   - "Picked for you" / "Discover" lands in O4.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final String greeting = greetingForHour(DateTime.now().hour);
    return Scaffold(
      appBar: AppBar(
        title: Text(greeting),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.queue_music_outlined),
            tooltip: 'Queue',
            onPressed: () => context.go(Routes.queue),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: const _HomeBody(),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      // AlwaysScrollable so the RefreshIndicator works even when content
      // doesn't fill the viewport (e.g. on the full-empty home state).
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: const <Widget>[
        _HomeSearchBar(),
        _QuickAccessGrid(),
        _JumpBackInSection(),
        _MostPlayedSection(),
        _RecommendationsSection(),
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
    return async.when(
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
                child: Text(
                  header,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              SizedBox(
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
