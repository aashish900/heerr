import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../player/heerr_audio_handler.dart';
import '../player/player_provider.dart';

/// Persistent media bar mounted above the bottom NavigationBar in
/// `_ShellScaffold`. Watches [playerSnapshotProvider]; renders only when the
/// snapshot has a current MediaItem. Hidden (zero-height) when the player
/// has nothing queued, when the snapshot stream is still loading, or when
/// `audioHandlerProvider` hasn't been overridden (router widget tests).
///
/// Tap on the bar (anywhere not on the play/pause button) → push `/player`.
/// Tap on the play/pause button → call handler.play() / handler.pause().
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PlayerSnapshot> snap =
        ref.watch(playerSnapshotProvider);
    final PlayerSnapshot? s = snap.valueOrNull;
    final MediaItem? item = s?.item;
    if (s == null || item == null) {
      return const SizedBox.shrink();
    }

    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
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
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (item.artist != null)
                      Text(
                        item.artist!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              _PlayPauseButton(playing: s.isPlaying),
              const SizedBox(width: 4),
            ],
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
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Widget placeholder = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(Icons.music_note, color: cs.onSurfaceVariant),
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
