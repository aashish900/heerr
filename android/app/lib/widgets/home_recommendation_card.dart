import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../models/recommended_track.dart';
import '../models/subsonic/song.dart';
import '../player/playback_actions.dart';
import '../providers/download.dart';
import 'download_icon.dart';
import 'error_snackbar.dart';
import 'library_cover_art.dart';

/// Vertical card used in the Home "Picked for you" / "Discover" section.
///
/// Square colour-swatch placeholder on top, title + artist below, then a
/// Play (in-library) or Download (remote) action button. Cover art lookup
/// for recommendation candidates would require an extra `getSong` round-
/// trip per row — deferred until users complain. v1 keeps the card visual
/// recognizable via the title/artist text and the colour-swatch top.
class HomeRecommendationCard extends ConsumerWidget {
  const HomeRecommendationCard({
    required this.track,
    this.width = 160,
    super.key,
  });

  final RecommendedTrack track;
  final double width;

  Future<void> _onDownload(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(downloadDispatcherProvider.notifier).dispatch(
            track.sourceUrl,
            sourceType: 'song',
            displayName: track.title,
          );
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
    final Song song = Song(id: id, title: track.title, artist: track.artist);
    await playSongFromSubsonic(ref, context, song);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme tt = Theme.of(context).textTheme;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool isPlayable = track.inLibrary && track.subsonicSongId != null;
    final bool inFlight = !isPlayable &&
        ref.watch(downloadDispatcherProvider
            .select((Set<String> s) => s.contains(track.sourceUrl)));

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: <Widget>[
                _CoverArt(
                  track: track,
                  size: width,
                  fallbackColor: cs.surfaceContainerHighest,
                  fallbackIconColor: cs.onSurfaceVariant,
                ),
                // Subtle overlay action: a centered play disc for in-library
                // tracks, or a bottom-right download chip for remote ones.
                if (isPlayable)
                  Positioned.fill(
                    child: Center(
                      child: _OverlayAction(
                        key: const Key('rec-play'),
                        tooltip: 'Play',
                        onPressed: () => unawaited(_onPlay(context, ref)),
                        child: const Icon(Icons.play_arrow,
                            size: 26, color: Colors.white),
                      ),
                    ),
                  )
                else
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: _OverlayAction(
                      key: const Key('rec-download'),
                      tooltip: 'Download',
                      onPressed: inFlight
                          ? null
                          : () => unawaited(_onDownload(context, ref)),
                      child: inFlight
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const DownloadIcon(filled: false, size: 20),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            track.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Subtle circular action overlaid on a recommendation card's cover art:
/// a translucent dark disc with a white glyph. Replaces the old full-width
/// filled buttons (#27) — keeps the action discoverable without dominating
/// the card. A null [onPressed] renders the disc non-interactive (e.g. a
/// download already in flight).
class _OverlayAction extends StatelessWidget {
  const _OverlayAction({
    required this.child,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final Widget child;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Three-way cover resolution for a recommendation card:
/// 1. Navidrome `coverArt` id present (in-library hit or Discover/random) →
///    use the cached [LibraryCoverArt] widget (disk + per-server cache).
/// 2. Backend-provided `coverUrl` present → load it via `Image.network`.
///    No auth, falls back to the placeholder on error (e.g. offline).
/// 3. Otherwise → solid colour swatch with a music-note icon.
class _CoverArt extends StatelessWidget {
  const _CoverArt({
    required this.track,
    required this.size,
    required this.fallbackColor,
    required this.fallbackIconColor,
  });

  final RecommendedTrack track;
  final double size;
  final Color fallbackColor;
  final Color fallbackIconColor;

  Widget _placeholder() {
    return Container(
      width: size,
      height: size,
      color: fallbackColor,
      child: Icon(
        Icons.music_note,
        size: 40,
        color: fallbackIconColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? cover = track.coverArt;
    if (cover != null && cover.isNotEmpty) {
      return LibraryCoverArt(
        coverArtId: cover,
        size: size,
        borderRadius: 0,
      );
    }
    final String? coverUrl = track.coverUrl;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      return Image.network(
        coverUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
            _placeholder(),
      );
    }
    return _placeholder();
  }
}
