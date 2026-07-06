import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../models/recommended_track.dart';
import '../providers/recommendations.dart';
import '../widgets/empty_state.dart';
import '../widgets/home_recommendation_card.dart';
import '../widgets/skeleton.dart';

/// "For You" — Phase N3. Reads [recommendationsProvider], renders
/// `(title, artist)` rows with a Download button per row, supports
/// pull-to-refresh, and surfaces loading/empty/error states inline.
///
/// Tapping Download dispatches via the existing `downloadDispatcherProvider`
/// (`POST /download` on the heerr backend). The button shows a small
/// spinner while the dispatch is in flight (same affordance as the search
/// result tile).
class RecommendationsScreen extends ConsumerStatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  ConsumerState<RecommendationsScreen> createState() =>
      _RecommendationsScreenState();
}

class _RecommendationsScreenState extends ConsumerState<RecommendationsScreen> {
  @override
  void dispose() {
    // Clear the "Find similar" seed when leaving — next visit returns to
    // the general "For You" feed. Use a post-frame microtask so we don't
    // mutate provider state mid-build.
    Future<void>.microtask(() {
      if (!mounted) return;
      ref.read(manualSeedProvider.notifier).state = null;
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<RecommendedTrack>> async =
        ref.watch(recommendationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('For You'),
        actions: <Widget>[
          // #38 — explicit "fetch new recommendations". Re-samples the seed
          // collection, so successive taps return different results.
          IconButton(
            key: const Key('for-you-refresh'),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(recommendationsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(recommendationsProvider.notifier).refresh(),
        child: async.when(
          loading: () => const _LoadingScroll(),
          error: (Object error, _) => _ErrorScroll(error: error),
          data: (List<RecommendedTrack> tracks) {
            if (tracks.isEmpty) {
              return const _EmptyScroll();
            }
            // #21: render the same cover-art cards as Home's "Picked for you"
            // section (HomeRecommendationCard) in a 2-column grid, instead of
            // the old bare title/artist rows. Card width is derived from the
            // viewport so the cover fills its cell and the aspect ratio keeps
            // the title/artist text below the cover unclipped.
            const double padding = 16;
            const double spacing = 12;
            final double cardWidth =
                (MediaQuery.of(context).size.width - padding * 2 - spacing) / 2;
            return GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(padding),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                // cover (cardWidth tall) + 8 gap + two text lines (~52).
                childAspectRatio: cardWidth / (cardWidth + 56),
              ),
              itemCount: tracks.length,
              itemBuilder: (BuildContext c, int i) => HomeRecommendationCard(
                track: tracks[i],
                width: cardWidth,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// SkeletonList is itself a `ListView`, so RefreshIndicator can drive its
/// scroll directly — no extra wrapping needed.
class _LoadingScroll extends StatelessWidget {
  const _LoadingScroll();

  @override
  Widget build(BuildContext context) => const SkeletonList(count: 6);
}

class _EmptyScroll extends StatelessWidget {
  const _EmptyScroll();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const <Widget>[
        SizedBox(height: 96),
        EmptyState(
          icon: Icons.recommend_outlined,
          title: 'Nothing to suggest yet',
          subtitle:
              'Star a few songs or play some music — recommendations need a '
              'starting point.',
        ),
      ],
    );
  }
}

class _ErrorScroll extends StatelessWidget {
  const _ErrorScroll({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final String message =
        error is ApiError ? (error as ApiError).message : error.toString();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        const SizedBox(height: 96),
        EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load recommendations',
          subtitle: message,
        ),
      ],
    );
  }
}
