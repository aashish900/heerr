import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/recommended_track.dart';
import '../../models/search_result_item.dart';
import '../../player/playback_actions.dart';
import '../../providers/download.dart';
import '../../providers/profiles/profile_meta.dart';
import '../../providers/recommendations.dart';
import '../../router.dart' show Routes;
import '../../theme.dart';
import '../../widgets/download_icon.dart';
import '../../widgets/home_recommendation_card.dart'
    show RecommendationCoverArt, downloadRecommendation;
import '../../widgets/recommendations_refresh_button.dart';

/// Home "For You" grid (heerr-home-for-you.html), between Quick Access and
/// Recently Added: every backend recommendation as a two-row grid of song
/// cards that slides sideways, filled column by column (0 over 1, 2 over 3,
/// …). Three columns fit the screen with a [_kPeek] of the fourth showing, so
/// the row reads as scrollable. Header: `Made for <nickname>`, then "For You"
/// with a refresh button beside it, then See all.
///
/// Hidden (zero height) until the feed has at least one result — first load,
/// error and empty all render nothing, so Home never shows a spinner or an
/// error here. During a refresh `valueOrNull` keeps the previous grid.
///
/// Since RX8 every result is a song the user does not own, so Play streams it
/// through the backend preview proxy ([playPreview]) — the same path as an
/// online search result. The bottom-left download button queues it via
/// [downloadRecommendation], same as the full For You screen.
class ForYouSection extends ConsumerWidget {
  const ForYouSection({super.key});

  static const int _kRows = 2;
  static const int _kVisibleColumns = 3;
  static const double _kGutter = 16;
  static const double _kGap = 10;
  static const double _kPeek = 24;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<RecommendedTrack> tracks =
        ref.watch(recommendationsProvider).valueOrNull ??
        const <RecommendedTrack>[];
    if (tracks.isEmpty) return const SizedBox.shrink();

    final ColorScheme cs = Theme.of(context).colorScheme;
    final String? nickname = ref
        .watch(profileMetaNotifierProvider)
        .valueOrNull
        ?.nickname;
    final List<List<RecommendedTrack>> columns = <List<RecommendedTrack>>[
      for (int i = 0; i < tracks.length; i += _kRows)
        tracks.sublist(i, math.min(i + _kRows, tracks.length)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      nickname == null ? 'Made for you' : 'Made for $nickname',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Row(
                      children: <Widget>[
                        Text(
                          'For You',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 4),
                        // Same spinning button as the For You screen: fetches
                        // a freshly sampled set; the grid stays until it lands.
                        RecommendationsRefreshButton(),
                      ],
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.push(Routes.libraryRecommendations),
                style: TextButton.styleFrom(foregroundColor: heerrMagenta),
                child: const Text('See all'),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final double cardWidth =
                (c.maxWidth - _kGutter - _kGap * _kVisibleColumns - _kPeek) /
                _kVisibleColumns;
            return SingleChildScrollView(
              // A new feed (refresh) gets a new key, so the row starts over
              // at the first recommendation instead of the old offset.
              key: ValueKey<String>(tracks.first.sourceUrl),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: _kGutter),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (int i = 0; i < columns.length; i++)
                    Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : _kGap),
                      child: SizedBox(
                        width: cardWidth,
                        child: Column(
                          children: <Widget>[
                            for (
                              int j = 0;
                              j < columns[i].length;
                              j++
                            ) ...<Widget>[
                              if (j > 0) const SizedBox(height: _kGap),
                              _ForYouCard(track: columns[i][j]),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ForYouCard extends ConsumerWidget {
  const _ForYouCard({required this.track});

  final RecommendedTrack track;

  void _play(BuildContext context, WidgetRef ref) {
    unawaited(
      playPreview(
        ref,
        context,
        SearchResultItem(
          sourceUrl: track.sourceUrl,
          sourceType: 'song',
          title: track.title,
          artist: track.artist,
          coverUrl: track.coverUrl,
          alreadyDownloaded: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey<String>('for-you-card'),
      color: cs.surfaceContainerHigh, // #1C1C1C
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outline), // #2E2E2E, 1px
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _play(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) {
                  final double size = c.maxWidth;
                  return Stack(
                    children: <Widget>[
                      ClipRRect(
                        key: const ValueKey<String>('for-you-art'),
                        borderRadius: BorderRadius.circular(10),
                        child: RecommendationCoverArt(
                          track: track,
                          size: size,
                          fallbackColor: cs.surfaceContainerHighest,
                          fallbackIconColor: cs.onSurfaceVariant,
                        ),
                      ),
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: _DownloadButton(track: track),
                      ),
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: _PlayButton(
                          tooltip: 'Play ${track.title}',
                          onPressed: () => _play(context, ref),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 32px translucent download disc on the art's bottom-left (same look as the
/// For You screen's download chip). Spins while the song is being queued;
/// taps then are ignored, so one tap = one `POST /download`.
// ponytail: 32 + 40 + 2*6 insets = 84px fits art >= 84, i.e. screens
// >= 370dp wide (art = (w - 70) / 3 - 16). Narrower phones overlap the two
// discs slightly; shrink the discs if such a device ever shows up.
class _DownloadButton extends ConsumerWidget {
  const _DownloadButton({required this.track});

  final RecommendedTrack track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool inFlight = ref.watch(
      downloadDispatcherProvider.select(
        (Set<String> s) => s.contains(track.sourceUrl),
      ),
    );
    return Tooltip(
      message: 'Download ${track.title}',
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: inFlight
              ? null
              : () => unawaited(downloadRecommendation(context, ref, track)),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Center(
              child: inFlight
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const DownloadIcon(filled: false, size: 18),
            ),
          ),
        ),
      ),
    );
  }
}

/// 40px magenta play disc overlaid on the art's bottom-right corner.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.tooltip, required this.onPressed});

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0x73000000), // black 45%
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: heerrMagenta,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                Icons.play_arrow_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
