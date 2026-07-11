import 'dart:ui' show ImageFilter;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../player/heerr_audio_handler.dart';
import '../../player/player_provider.dart';
import '../../providers/player/art_palette.dart';
import '../../theme.dart';
import '../../utils/palette.dart';
import '../../widgets/animated_tint.dart';
import '../../widgets/waveform_strip.dart';

/// Hero "Continue Listening" card (mockup zone 4 — HOMESCREEN.md task 2,
/// adaptive theming task B2).
///
/// Driven entirely by [playerSnapshotProvider]: on cold start the
/// NowPlayingPersistence restore repopulates the handler (paused), so the
/// last-played track surfaces here without reading NowPlayingStore directly.
/// Hidden when nothing is queued, while the stream is loading, or when
/// `audioHandlerProvider` isn't overridden (router widget tests) — same
/// guard pattern as the MiniPlayer.
///
/// Part B: the artwork is never recoloured. Instead the chrome adapts —
/// a blurred copy of the cover fills the card under a darkening gradient,
/// and the waveform / glows take `brandBlend(extracted cover colour)`,
/// cross-faded on track change. The progress fill stays `heerrGradient`
/// (brand anchor).
///
/// The progress display is static per snapshot emission (play/pause/seek/
/// track change) — deliberately no per-second ticker on Home. Seeking lives
/// on /player; tapping the card goes there.
class ContinueListeningCard extends ConsumerStatefulWidget {
  const ContinueListeningCard({super.key});

  @override
  ConsumerState<ContinueListeningCard> createState() =>
      _ContinueListeningCardState();
}

class _ContinueListeningCardState
    extends ConsumerState<ContinueListeningCard> {
  // Last successfully extracted colour — keeps the previous tint on screen
  // while the palette future for a new track resolves (no fallback flash).
  Color? _lastExtracted;

  static String _fmt(Duration d) {
    final int m = d.inMinutes;
    final int s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<PlayerSnapshot> snap = ref.watch(playerSnapshotProvider);
    final PlayerSnapshot? s = snap.valueOrNull;
    final MediaItem? item = s?.item;
    if (s == null || item == null) return const SizedBox.shrink();

    final Uri? artUri = item.artUri;
    final AsyncValue<Color?>? palette = artUri == null
        ? null
        : ref.watch(artPaletteProvider(artUri.toString()));
    if (palette != null && palette.hasValue) {
      _lastExtracted = palette.value;
    } else if (artUri == null) {
      _lastExtracted = null;
    }
    final Color tint = brandBlend(_lastExtracted ?? heerrPurple);

    final TextTheme tt = Theme.of(context).textTheme;
    final ColorScheme cs = Theme.of(context).colorScheme;

    final Duration position = s.position;
    final Duration? duration = item.duration;
    final double progress = (duration == null || duration.inMilliseconds == 0)
        ? 0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    return AnimatedTint(
      tint: tint,
      builder: (BuildContext context, Color tint) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        // Thin gradient border: gradient outer shell + near-black inner card
        // (same ring technique as the Home profile avatar).
        child: Container(
          decoration: BoxDecoration(
            gradient: heerrGradient,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(1.5),
          child: Material(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(22.5),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const Key('continue-listening-card'),
              onTap: () => context.push('/player'),
              child: Stack(
                children: <Widget>[
                  // B2 backdrop: the cover blurred + stretched across the
                  // whole card. ImageFiltered (not BackdropFilter) — only
                  // the image itself needs blurring, which is the cheaper
                  // path. RepaintBoundary isolates the blur from list
                  // repaints while scrolling.
                  if (artUri != null)
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: kArtBackdropBlur,
                            sigmaY: kArtBackdropBlur,
                          ),
                          child: Image.network(
                            artUri.toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  // Darkening gradient so the text column passes contrast:
                  // lighter over the sharp art, near-black under the text.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: <Color>[
                            Colors.black.withValues(alpha: 0.35),
                            heerrBlack.withValues(alpha: 0.88),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Neon glow behind the sharp art (mockup's ring feel
                      // without touching the artwork pixels).
                      Container(
                        width: 140,
                        decoration: BoxDecoration(
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: tint.withValues(alpha: 0.25),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: _CoverArt(artUri: artUri),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const _Badge(),
                              const SizedBox(height: 8),
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.artist ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.bodyMedium
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                              const SizedBox(height: 10),
                              WaveformStrip(
                                height: 22,
                                color: tint,
                                seed: item.title.hashCode,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: <Widget>[
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: <Widget>[
                                        _ProgressBar(progress: progress),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: <Widget>[
                                            Text(
                                              _fmt(position),
                                              style: tt.bodySmall?.copyWith(
                                                  color: cs.onSurfaceVariant),
                                            ),
                                            Text(
                                              duration == null
                                                  ? '--:--'
                                                  : _fmt(duration),
                                              style: tt.bodySmall?.copyWith(
                                                  color: cs.onSurfaceVariant),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _PlayButton(
                                    playing: s.isPlaying,
                                    tint: tint,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'CONTINUE LISTENING',
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(letterSpacing: 1.2),
      ),
    );
  }
}

class _CoverArt extends StatelessWidget {
  const _CoverArt({required this.artUri});

  final Uri? artUri;

  @override
  Widget build(BuildContext context) {
    final Widget placeholder = ColoredBox(
      color: Colors.black26,
      child: Icon(
        Icons.music_note,
        size: 48,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
    final Uri? uri = artUri;
    if (uri == null) return placeholder;
    return Image.network(
      uri.toString(),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}

/// Static progress display: gradient fill over a faint track. Not a slider —
/// seeking stays on /player. Deliberately keeps the brand gradient (not the
/// per-song tint) so the heerr identity anchors every card.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 5,
        child: Stack(
          children: <Widget>[
            const Positioned.fill(
              child: ColoredBox(color: Color(0x33FFFFFF)),
            ),
            FractionallySizedBox(
              key: const Key('continue-listening-progress'),
              widthFactor: progress,
              child: const DecoratedBox(
                decoration: BoxDecoration(gradient: heerrGradient),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends ConsumerWidget {
  const _PlayButton({required this.playing, required this.tint});

  final bool playing;
  final Color tint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      key: const Key('continue-listening-play'),
      customBorder: const CircleBorder(),
      onTap: () {
        final HeerrAudioHandler handler = ref.read(audioHandlerProvider);
        if (playing) {
          handler.pause();
        } else {
          handler.play();
        }
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: heerrGradient,
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: tint.withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          playing ? Icons.pause : Icons.play_arrow,
          color: Colors.black,
          size: 30,
        ),
      ),
    );
  }
}
