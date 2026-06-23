import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../player/heerr_audio_handler.dart';
import '../player/player_provider.dart';
import '../theme.dart';
import '../utils/palette.dart';
import 'preview_badge.dart';

/// Test seam — swap with a deterministic fake (e.g. `(_) async => null`) so
/// widget tests don't hit the network and don't depend on `palette_generator`.
typedef MiniPlayerPaletteExtractor = Future<Color?> Function(Uri? artUri);

@visibleForTesting
MiniPlayerPaletteExtractor miniPlayerPaletteExtractorOverride =
    dominantColorFor;

/// Persistent media bar mounted above the bottom NavigationBar in
/// `_ShellScaffold`. Watches [playerSnapshotProvider]; renders only when the
/// snapshot has a current MediaItem. Hidden (zero-height) when the player
/// has nothing queued, when the snapshot stream is still loading, or when
/// `audioHandlerProvider` hasn't been overridden (router widget tests).
///
/// Tap on the bar (anywhere not on the play/pause button) → push `/player`.
/// Tap on the play/pause button → call handler.play() / handler.pause().
///
/// Background colour is the dominant colour of the current cover at 75%
/// alpha; falls back to [heerrGolden] while extraction is pending or fails.
class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({super.key});

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer> {
  Uri? _tintArtUri;
  Color? _tintColor;

  void _maybeRefreshTint(Uri? artUri) {
    if (artUri == _tintArtUri) return;
    _tintArtUri = artUri;
    final Uri? captured = artUri;
    miniPlayerPaletteExtractorOverride(captured).then((Color? c) {
      if (!mounted) return;
      // Stale-response guard: another item may have started while we were
      // extracting; only apply this colour if the current artUri still
      // matches the one we kicked off the extraction for.
      if (_tintArtUri != captured) return;
      setState(() => _tintColor = c);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<PlayerSnapshot> snap =
        ref.watch(playerSnapshotProvider);
    final PlayerSnapshot? s = snap.valueOrNull;
    final MediaItem? item = s?.item;
    if (s == null || item == null) {
      return const SizedBox.shrink();
    }

    _maybeRefreshTint(item.artUri);
    final Color bg = (_tintColor ?? heerrGolden).withValues(alpha: 0.55);

    return Padding(
      // 99% width → 0.5% margin on each side. Tiny vertical gap so the pill
      // floats above the nav bar instead of touching it.
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 6),
      child: FractionallySizedBox(
        widthFactor: 0.99,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(9),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/player'),
            child: SizedBox(
              height: 56,
              child: Row(
                children: <Widget>[
                  const SizedBox(width: 8),
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
                                        ?.copyWith(color: Colors.white70),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  _PlayPauseButton(playing: s.isPlaying),
                  const SizedBox(width: 8),
                ],
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
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(Icons.music_note, color: Colors.white70),
    );
    final Uri? uri = artUri;
    if (uri == null) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        uri.toString(),
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}

class _PlayPauseButton extends ConsumerWidget {
  const _PlayPauseButton({required this.playing});

  final bool playing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: playing ? 'Pause' : 'Play',
      color: Colors.white,
      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
      onPressed: () {
        final HeerrAudioHandler handler = ref.read(audioHandlerProvider);
        if (playing) {
          handler.pause();
        } else {
          handler.play();
        }
      },
    );
  }
}
