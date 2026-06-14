import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../models/recommended_track.dart';
import '../models/subsonic/song.dart';
import '../player/playback_actions.dart';
import '../providers/download.dart';
import '../providers/recommendations.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_snackbar.dart';
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
      appBar: AppBar(title: const Text('For You')),
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
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: tracks.length,
              itemBuilder: (BuildContext c, int i) =>
                  _RecommendationTile(track: tracks[i]),
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

/// One row of the recommendations list.
///
/// When `track.inLibrary` is true and a `subsonicSongId` is attached
/// (set by N4 cross-reference), the trailing slot renders a **Play**
/// button that drives Subsonic playback via [playSongFromSubsonic]. The
/// usual case — remote-only candidates — renders the Download button
/// (reads only the in-flight set for *this* row's URL so other rows'
/// dispatches don't repaint it).
class _RecommendationTile extends ConsumerWidget {
  const _RecommendationTile({required this.track});

  final RecommendedTrack track;

  Future<void> _onDownload(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(downloadDispatcherProvider.notifier)
          .dispatch(track.sourceUrl, sourceType: 'song', displayName: track.title);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: kSnackBarDuration,
          content: Text('Queued "${track.title}"'),
        ),
      );
    } on ApiError catch (e) {
      if (!context.mounted) return;
      showApiError(context, e, action: 'download');
    }
  }

  Future<void> _onPlay(BuildContext context, WidgetRef ref) async {
    final String? id = track.subsonicSongId;
    if (id == null) return;
    // Build a synthetic Song from what we have — `playSongFromSubsonic`
    // only reads id/title/artist for the stream URL + queue label, and
    // we don't want to round-trip through `getSong` for one play.
    final Song song = Song(id: id, title: track.title, artist: track.artist);
    await playSongFromSubsonic(ref, context, song);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (track.inLibrary && track.subsonicSongId != null) {
      return ListTile(
        title: Text(track.title),
        subtitle: Text(track.artist),
        trailing: FilledButton.icon(
          onPressed: () => unawaited(_onPlay(context, ref)),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Play'),
        ),
      );
    }

    final bool inFlight = ref.watch(
      downloadDispatcherProvider.select(
        (Set<String> s) => s.contains(track.sourceUrl),
      ),
    );

    return ListTile(
      title: Text(track.title),
      subtitle: Text(track.artist),
      trailing: FilledButton.icon(
        onPressed: inFlight ? null : () => unawaited(_onDownload(context, ref)),
        icon: inFlight
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download),
        label: const Text('Download'),
      ),
    );
  }
}
