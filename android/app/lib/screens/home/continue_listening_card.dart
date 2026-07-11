import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../player/heerr_audio_handler.dart';
import '../../player/player_provider.dart';
import '../../theme.dart';
import '../../widgets/waveform_strip.dart';

/// Hero "Continue Listening" card (mockup zone 4 — HOMESCREEN.md task 2).
///
/// Driven entirely by [playerSnapshotProvider]: on cold start the
/// NowPlayingPersistence restore repopulates the handler (paused), so the
/// last-played track surfaces here without reading NowPlayingStore directly.
/// Hidden when nothing is queued, while the stream is loading, or when
/// `audioHandlerProvider` isn't overridden (router widget tests) — same
/// guard pattern as the MiniPlayer.
///
/// The progress display is static per snapshot emission (play/pause/seek/
/// track change) — deliberately no per-second ticker on Home. Seeking lives
/// on /player; tapping the card goes there.
class ContinueListeningCard extends ConsumerWidget {
  const ContinueListeningCard({super.key});

  static String _fmt(Duration d) {
    final int m = d.inMinutes;
    final int s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PlayerSnapshot> snap = ref.watch(playerSnapshotProvider);
    final PlayerSnapshot? s = snap.valueOrNull;
    final MediaItem? item = s?.item;
    if (s == null || item == null) return const SizedBox.shrink();

    final TextTheme tt = Theme.of(context).textTheme;
    final ColorScheme cs = Theme.of(context).colorScheme;

    final Duration position = s.position;
    final Duration? duration = item.duration;
    final double progress = (duration == null || duration.inMilliseconds == 0)
        ? 0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    return Padding(
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(width: 140, child: _CoverArt(artUri: item.artUri)),
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
                        WaveformStrip(height: 22, seed: item.title.hashCode),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            _PlayButton(playing: s.isPlaying),
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
/// seeking stays on /player.
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
  const _PlayButton({required this.playing});

  final bool playing;

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
        decoration: const BoxDecoration(
          gradient: heerrGradient,
          shape: BoxShape.circle,
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
