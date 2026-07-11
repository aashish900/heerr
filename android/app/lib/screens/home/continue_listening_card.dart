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
/// Part B: the artwork is never recoloured. Instead the chrome adapts — the
/// waveform + play-button glow take `brandBlend(extracted cover colour)`,
/// cross-faded on track change. The progress fill stays `heerrGradient`
/// (brand anchor). The card background itself stays solid (matching the
/// mockup, which keeps the text half plain black) — an earlier revision
/// bled a blurred copy of the cover across the whole card as a backdrop;
/// dropped per user review as a visual mismatch from the source.
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
        // Thin single-colour hairline, not a gradient ring — matches the
        // mockup's subtle magenta outline (a full heerrGradient ring read
        // as busier/more colorful than the source; dropped per user review).
        child: Material(
          color: cs.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: heerrMagenta.withValues(alpha: 0.5),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('continue-listening-card'),
            onTap: () => context.push('/player'),
            // Fixed height: the card sits in Home's ListView, where
            // children get unbounded height — the stretch-Row inside
            // this Row must have a bound or layout blows up (which
            // killed everything below the card when a track was live).
            child: SizedBox(
              height: 212,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Neon glow behind the sharp art (mockup's ring feel
                  // without touching the artwork pixels). Width matches
                  // the mockup's roughly-half-card art tile (+15% over the
                  // original 140 per user review).
                  Container(
                    width: 161,
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
                        mainAxisAlignment: MainAxisAlignment.center,
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
                            animate: s.isPlaying,
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

/// Progress display: gradient fill over a faint track, with a round thumb
/// at the current position (matches the mockup's visible knob). Not an
/// actual slider — seeking stays on /player; the knob is indicative only.
/// Deliberately keeps the brand gradient (not the per-song tint) so the
/// heerr identity anchors every card.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final double progress;

  static const double _knobDiameter = 12;
  static const double _rowHeight = 14;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _rowHeight,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double trackWidth = constraints.maxWidth;
          final double knobLeft =
              (progress * trackWidth - _knobDiameter / 2)
                  .clamp(0.0, trackWidth - _knobDiameter);
          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Align(
                child: ClipRRect(
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
                          heightFactor: 1.0,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(gradient: heerrGradient),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: knobLeft,
                top: (_rowHeight - _knobDiameter) / 2,
                child: Container(
                  key: const Key('continue-listening-progress-knob'),
                  width: _knobDiameter,
                  height: _knobDiameter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: heerrGradient,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: heerrMagenta.withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Thin circular outline with a transparent center and a gradient-filled
/// icon — matches the mockup's ring button (a solid gradient-filled disc
/// read as heavier than the source; dropped per user review).
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
          shape: BoxShape.circle,
          border: Border.all(color: tint, width: 1.5),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: tint.withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: ShaderMask(
            shaderCallback: (Rect bounds) => heerrGradient.createShader(bounds),
            child: Icon(
              playing ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}
