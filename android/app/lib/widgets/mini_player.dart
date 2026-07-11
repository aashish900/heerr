import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../player/heerr_audio_handler.dart';
import '../player/player_provider.dart';
import '../providers/player/art_palette.dart';
import '../theme.dart';
import '../utils/palette.dart';
import 'animated_tint.dart';
import 'preview_badge.dart';
import 'waveform_strip.dart';

/// Persistent media bar mounted above the bottom NavigationBar in
/// `_ShellScaffold`. Watches [playerSnapshotProvider]; renders only when the
/// snapshot has a current MediaItem. Hidden (zero-height) when the player
/// has nothing queued, when the snapshot stream is still loading, or when
/// `audioHandlerProvider` hasn't been overridden (router widget tests).
///
/// 2026-07 redesign (HOMESCREEN.md task 7): dark card + thin gradient
/// border + decorative waveform + gradient play circle, matching the Home
/// hero card's design language. The cover-derived dominant colour now tints
/// the waveform (was: the whole bar background); Part B migrates the
/// extraction to the shared cached palette provider.
///
/// Tap on the bar (anywhere not on the play/pause button) → push `/player`.
/// Tap on the play/pause button → call handler.play() / handler.pause().
class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({super.key});

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer> {
  // Last successfully extracted colour — keeps the previous tint on screen
  // while the palette future for a new track is still resolving, so track
  // skips cross-fade instead of flashing the fallback (Part B, B3).
  Color? _lastExtracted;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<PlayerSnapshot> snap =
        ref.watch(playerSnapshotProvider);
    final PlayerSnapshot? s = snap.valueOrNull;
    final MediaItem? item = s?.item;
    if (s == null || item == null) {
      return const SizedBox.shrink();
    }

    // B1: shared cached palette provider (keyed by art URI — the family
    // makes stale-response clobbering structurally impossible).
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
    final ColorScheme cs = Theme.of(context).colorScheme;

    return AnimatedTint(
      tint: tint,
      builder: (BuildContext context, Color tint) => Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
      // Thin gradient border, same shell technique as the Home hero card.
      child: Container(
        decoration: BoxDecoration(
          gradient: heerrGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(1.2),
        child: Material(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14.8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/player'),
            child: SizedBox(
              height: 64,
              child: LayoutBuilder(
                builder: (BuildContext c, BoxConstraints box) {
                  // Hide the decorative waveform when the bar is narrow
                  // (small screens / split view) — text wins.
                  final bool showWave = box.maxWidth >= 360;
                  return Row(
                    children: <Widget>[
                      const SizedBox(width: 10),
                      _CoverThumb(artUri: item.artUri),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isPreviewMediaItem(item) ||
                                item.artist != null) ...<Widget>[
                              const SizedBox(height: 2),
                              Row(
                                children: <Widget>[
                                  if (isPreviewMediaItem(item)) ...<Widget>[
                                    const PreviewBadge(
                                      background: Colors.white24,
                                      foreground: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  if (item.artist != null)
                                    Flexible(
                                      child: Text(
                                        item.artist!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                color: Colors.white70),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (showWave) ...<Widget>[
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 90,
                          child: WaveformStrip(
                            height: 20,
                            color: tint,
                            seed: item.title.hashCode,
                          ),
                        ),
                      ],
                      const SizedBox(width: 10),
                      _PlayPauseButton(playing: s.isPlaying, tint: tint),
                      const SizedBox(width: 10),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({required this.artUri});

  final Uri? artUri;

  @override
  Widget build(BuildContext context) {
    final Widget placeholder = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.music_note, color: Colors.white70),
    );
    final Uri? uri = artUri;
    if (uri == null) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        uri.toString(),
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}

class _PlayPauseButton extends ConsumerWidget {
  const _PlayPauseButton({required this.playing, required this.tint});

  final bool playing;
  final Color tint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: heerrGradient,
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: tint.withValues(alpha: 0.25),
              blurRadius: 16,
            ),
          ],
        ),
        child: Icon(
          playing ? Icons.pause : Icons.play_arrow,
          color: Colors.black,
          size: 24,
        ),
      ),
    );
  }
}
