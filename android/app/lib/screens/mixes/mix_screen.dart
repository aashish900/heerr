import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_error.dart';
import '../../models/mix.dart';
import '../../models/recommended_track.dart';
import '../../models/search_result_item.dart';
import '../../player/playback_actions.dart';
import '../../providers/mixes.dart';
import '../../providers/profiles/profile_meta.dart';
import '../home/your_mixes_section.dart' show vibeStyle;
import '../../widgets/empty_state.dart';
import '../../widgets/home_recommendation_card.dart'
    show RecommendationCoverArt, RecommendationDownloadButton, previewItemFor;
import '../../widgets/skeleton.dart';

/// A vibe mix (Phase MX, `/mixes/:id`): header (cover, title, who it's made
/// for, song count, Play all), then every song — tap a row to play the mix
/// from there, or download it. Songs are previews (none are owned), so Play
/// all / row taps queue them through [playPreviews].
class MixScreen extends ConsumerWidget {
  const MixScreen({required this.vibeId, super.key});

  final String vibeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<MixResponse> async = ref.watch(
      mixNotifierProvider(vibeId),
    );
    final String title =
        async.valueOrNull?.title ??
        _vibeTitle(ref.watch(mixVibesProvider).valueOrNull) ??
        'Mix';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: <Widget>[_RegenerateButton(vibeId: vibeId)],
      ),
      body: async.when(
        loading: () => const SkeletonList(count: 8),
        error: (Object e, _) => _ErrorBody(
          message: e is ApiError ? e.message : e.toString(),
          onRetry: () => ref.invalidate(mixNotifierProvider(vibeId)),
        ),
        data: (MixResponse mix) => mix.results.isEmpty
            ? const _EmptyBody()
            // A regenerate keeps the old list visible (dimmed) until the new
            // one lands, like the For You screen.
            : AnimatedOpacity(
                opacity: async.isLoading ? 0.4 : 1,
                duration: const Duration(milliseconds: 200),
                child: _MixList(mix: mix),
              ),
      ),
    );
  }

  String? _vibeTitle(List<MixVibe>? vibes) {
    for (final MixVibe v in vibes ?? const <MixVibe>[]) {
      if (v.id == vibeId) return v.title;
    }
    return null;
  }
}

class _MixList extends ConsumerWidget {
  const _MixList({required this.mix});

  final MixResponse mix;

  void _play(BuildContext context, WidgetRef ref, int startIndex) {
    final List<SearchResultItem> items = mix.results
        .map(previewItemFor)
        .toList();
    unawaited(playPreviews(ref, context, items, startIndex: startIndex));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    final String? nickname = ref
        .watch(profileMetaNotifierProvider)
        .valueOrNull
        ?.nickname;
    final String madeFor = !mix.personalized
        ? 'Popular picks for this vibe'
        : nickname == null
        ? 'Made for you'
        : 'Made for $nickname';
    final int n = mix.results.length;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: n + 1,
      itemBuilder: (BuildContext context, int i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: vibeStyle(mix.id).gradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        vibeStyle(mix.id).icon,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            mix.title,
                            style: tt.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            madeFor,
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            n == 1 ? '1 song' : '$n songs',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _play(context, ref, 0),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Play all'),
                ),
              ],
            ),
          );
        }
        final RecommendedTrack t = mix.results[i - 1];
        return ListTile(
          onTap: () => _play(context, ref, i - 1),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: RecommendationCoverArt(
              track: t,
              size: 48,
              fallbackColor: cs.surfaceContainerHighest,
              fallbackIconColor: cs.onSurfaceVariant,
            ),
          ),
          title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            t.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: RecommendationDownloadButton(track: t),
        );
      },
    );
  }
}

/// Spinning while the mix (re)loads; taps then are ignored.
class _RegenerateButton extends ConsumerWidget {
  const _RegenerateButton({required this.vibeId});

  final String vibeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool busy = ref.watch(
      mixNotifierProvider(
        vibeId,
      ).select((AsyncValue<MixResponse> s) => s.isLoading),
    );
    return IconButton(
      tooltip: 'Regenerate mix',
      onPressed: busy
          ? null
          : () => unawaited(
              ref.read(mixNotifierProvider(vibeId).notifier).regenerate(),
            ),
      icon: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const <Widget>[
        SizedBox(height: 96),
        EmptyState(
          icon: Icons.queue_music,
          title: 'Nothing new for this vibe',
          subtitle: 'You already have everything in this mix. Try Regenerate.',
        ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        const SizedBox(height: 96),
        EmptyState(
          icon: Icons.error_outline,
          title: "Couldn't load this mix",
          subtitle: message,
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}
