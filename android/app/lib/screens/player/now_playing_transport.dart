part of 'now_playing_screen.dart';

/// NOWPLAYING.md NP5 — thin wrapper over [WaveformSeekBar], keeping the
/// `_Scrubber` name/call shape so `_Body`'s call site didn't need touching
/// beyond adding [playing] / [seed].
class _Scrubber extends StatelessWidget {
  const _Scrubber({
    required this.position,
    required this.duration,
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
    required this.playing,
    required this.seed,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeekStart;
  final ValueChanged<Duration> onSeekUpdate;
  final ValueChanged<Duration> onSeekEnd;
  final bool playing;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return WaveformSeekBar(
      position: position,
      duration: duration,
      onSeekStart: onSeekStart,
      onSeekUpdate: onSeekUpdate,
      onSeekEnd: onSeekEnd,
      animate: playing,
      seed: seed,
    );
  }
}

/// Scales [child] down to 0.92 while pressed (NOWPLAYING.md NP6). Uses
/// [Listener] rather than a [GestureDetector] so it observes raw pointer
/// events without joining the gesture arena — the wrapped [IconButton]'s own
/// tap recognition is completely untouched. [AnimatedScale] is an implicit
/// animation (always converges), so it never risks a `pumpAndSettle` hang
/// the way a repeating [AnimationController] would.
class _TapScale extends StatefulWidget {
  const _TapScale({required this.child});

  final Widget child;

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}

/// A transport glyph (shuffle / repeat) rendered from a bundled SVG. When
/// [active] it takes the magenta→purple→violet [heerrGradient] via
/// [GradientIcon]; otherwise it renders solid in [inactiveColor].
Widget _transportGlyph(
  String asset, {
  required bool active,
  required Color inactiveColor,
}) {
  final Widget svg = SvgPicture.asset(
    asset,
    width: 26,
    height: 26,
    colorFilter: ColorFilter.mode(
      active ? Colors.white : inactiveColor,
      BlendMode.srcIn,
    ),
  );
  return active ? GradientIcon(child: svg) : svg;
}

class _Transport extends ConsumerWidget {
  const _Transport({
    required this.playing,
    required this.repeatMode,
    required this.shuffleMode,
  });

  final bool playing;
  final AudioServiceRepeatMode repeatMode;
  final AudioServiceShuffleMode shuffleMode;

  AudioServiceRepeatMode _nextRepeat(AudioServiceRepeatMode current) =>
      switch (current) {
        AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
        AudioServiceRepeatMode.all => AudioServiceRepeatMode.one,
        _ => AudioServiceRepeatMode.none,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool shuffleOn = shuffleMode != AudioServiceShuffleMode.none;
    final bool repeatOn = repeatMode != AudioServiceRepeatMode.none;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        // Shuffle: custom curvy glyph, accent-tinted when active. Material's
        // shuffle_rounded only rounds stroke corners — the flowing crossed
        // arrows in the reference design need a bundled SVG.
        _TapScale(
          child: IconButton(
            key: const Key('now-playing-shuffle'),
            tooltip: shuffleOn ? 'Shuffle on' : 'Shuffle off',
            icon: _transportGlyph(
              'assets/icons/shuffle.svg',
              active: shuffleOn,
              inactiveColor: cs.onSurfaceVariant,
            ),
            onPressed: () {
              final HeerrAudioHandler h = ref.read(audioHandlerProvider);
              h.setShuffleMode(shuffleOn
                  ? AudioServiceShuffleMode.none
                  : AudioServiceShuffleMode.all);
            },
          ),
        ),
        _TapScale(
          child: IconButton(
            iconSize: 36,
            tooltip: 'Previous',
            icon: const Icon(Icons.skip_previous_rounded),
            onPressed: () => ref.read(audioHandlerProvider).skipToPrevious(),
          ),
        ),
        // Big gradient circle (magenta→purple→violet) with a black glyph and
        // a soft magenta glow — the app's primary action, matching the
        // reference layout.
        _TapScale(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: heerrGradient,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: heerrMagenta.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: IconButton(
              iconSize: 44,
              tooltip: playing ? 'Pause' : 'Play',
              color: Colors.black,
              padding: const EdgeInsets.all(14),
              icon: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
              onPressed: () {
                final HeerrAudioHandler h = ref.read(audioHandlerProvider);
                if (playing) {
                  h.pause();
                } else {
                  h.play();
                }
              },
            ),
          ),
        ),
        _TapScale(
          child: IconButton(
            iconSize: 36,
            tooltip: 'Next',
            icon: const Icon(Icons.skip_next_rounded),
            onPressed: () => ref.read(audioHandlerProvider).skipToNext(),
          ),
        ),
        // Repeat: custom rounded-loop glyph (bundled SVG, same reason as
        // shuffle), accent-tinted when active.
        _TapScale(
          child: IconButton(
            key: const Key('now-playing-repeat'),
            tooltip: repeatMode == AudioServiceRepeatMode.one
                ? 'Repeat one'
                : repeatOn
                    ? 'Repeat all'
                    : 'Repeat off',
            icon: _transportGlyph(
              repeatMode == AudioServiceRepeatMode.one
                  ? 'assets/icons/repeat_one.svg'
                  : 'assets/icons/repeat.svg',
              active: repeatOn,
              inactiveColor: cs.onSurfaceVariant,
            ),
            onPressed: () => ref
                .read(audioHandlerProvider)
                .setRepeatMode(_nextRepeat(repeatMode)),
          ),
        ),
      ],
    );
  }
}

/// Row below transport with the queue trigger. The device-picker placeholder
/// moved to the header in NP2 (NOWPLAYING.md §2.3).
class _BottomActionsRow extends StatelessWidget {
  const _BottomActionsRow({required this.onQueueTap});

  final VoidCallback onQueueTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          IconButton(
            key: const Key('now-playing-queue-button'),
            icon: const Icon(Icons.queue_music_rounded),
            tooltip: 'Queue',
            onPressed: onQueueTap,
          ),
        ],
      ),
    );
  }
}

class _QueueList extends ConsumerWidget {
  const _QueueList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<MediaItem>> q = ref.watch(playerQueueProvider);
    final AsyncValue<MediaItem?> current =
        ref.watch(currentMediaItemProvider);
    final String? currentId = current.valueOrNull?.id;
    return q.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, _) => Center(child: Text('Queue error: $e')),
      data: (List<MediaItem> items) {
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Queue is empty.'),
            ),
          );
        }
        return ReorderableListView.builder(
          buildDefaultDragHandles: false,
          itemCount: items.length,
          onReorderItem: (int oldIndex, int newIndex) {
            ref.read(audioHandlerProvider).moveQueueItem(oldIndex, newIndex);
          },
          itemBuilder: (BuildContext c, int i) {
            final MediaItem m = items[i];
            final bool isCurrent = m.id == currentId;
            return Dismissible(
              key: ValueKey<String>('queue-row-$i-${m.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Theme.of(c).colorScheme.errorContainer,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                child: Icon(
                  Icons.delete_outline,
                  color: Theme.of(c).colorScheme.onErrorContainer,
                ),
              ),
              onDismissed: (_) =>
                  ref.read(audioHandlerProvider).removeQueueItemAt(i),
              child: ListTile(
                leading: Icon(
                  isCurrent ? Icons.equalizer : Icons.music_note,
                  color: isCurrent
                      ? Theme.of(c).colorScheme.primary
                      : null,
                ),
                title: Text(
                  m.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.w600 : null,
                  ),
                ),
                subtitle: m.artist == null
                    ? null
                    : Text(m.artist!,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: ReorderableDragStartListener(
                  index: i,
                  child: const Icon(Icons.drag_handle),
                ),
                onTap: () =>
                    ref.read(audioHandlerProvider).skipToQueueItem(i),
              ),
            );
          },
        );
      },
    );
  }
}
