import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../models/recommended_track.dart';
import '../models/subsonic/song.dart';
import '../player/playback_actions.dart';
import '../providers/download.dart';
import 'error_snackbar.dart';
import 'library_cover_art.dart';

/// Extracts the YouTube `videoId` from a `music.youtube.com/watch?v=<id>` URL
/// (or the youtube.com equivalent). Returns null if the URL is empty, not a
/// YouTube watch URL, or missing the `v` query param. Public for tests.
String? extractYoutubeVideoId(String url) {
  if (url.isEmpty) return null;
  final Uri? uri = Uri.tryParse(url);
  if (uri == null) return null;
  if (!uri.host.contains('youtube.com') && !uri.host.contains('youtu.be')) {
    return null;
  }
  if (uri.host.contains('youtu.be')) {
    return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
  }
  final String? v = uri.queryParameters['v'];
  if (v == null || v.isEmpty) return null;
  return v;
}

/// YouTube thumbnail URL for a given videoId — public, no auth required.
/// `mqdefault` is the medium-quality 320×180 thumbnail; always present even
/// for tracks that have no upscaled `hqdefault`/`maxresdefault` variant.
String youtubeThumbnailUrl(String videoId) =>
    'https://img.youtube.com/vi/$videoId/mqdefault.jpg';

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
            child: _CoverArt(
              track: track,
              size: width,
              fallbackColor: cs.surfaceContainerHighest,
              fallbackIconColor: cs.onSurfaceVariant,
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
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: isPlayable
                ? FilledButton.icon(
                    onPressed: () => unawaited(_onPlay(context, ref)),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Play'),
                  )
                : FilledButton.icon(
                    onPressed: inFlight
                        ? null
                        : () => unawaited(_onDownload(context, ref)),
                    icon: inFlight
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download, size: 18),
                    label: const Text('Download'),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Three-way cover resolution for a recommendation card:
/// 1. Navidrome `coverArt` id present (in-library hit or Discover/random) →
///    use the cached [LibraryCoverArt] widget (disk + per-server cache).
/// 2. `sourceUrl` parses as a YouTube `watch?v=<id>` → load the public
///    `img.youtube.com` thumbnail via `Image.network`. No auth, falls back
///    to the placeholder on error (e.g. offline / no connectivity).
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
    final String? videoId = extractYoutubeVideoId(track.sourceUrl);
    if (videoId != null) {
      return Image.network(
        youtubeThumbnailUrl(videoId),
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
