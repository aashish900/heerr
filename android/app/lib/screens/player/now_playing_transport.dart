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

/// Cover-art thumb for a queue row. Queue [MediaItem]s only carry a
/// resolved [Uri] (no raw Subsonic `coverArtId`), so this is a direct
/// [Image.network] — the same pattern `_CornerArt` already uses elsewhere
/// in this screen — rather than `LibraryCoverArt`, which needs a
/// `coverArtId` to drive its own offline cache.
class _QueueRowArt extends StatelessWidget {
  const _QueueRowArt({required this.artUri});

  static const double _size = 44;

  final Uri? artUri;

  @override
  Widget build(BuildContext context) {
    final Widget placeholder = Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.music_note, color: Colors.white54, size: 20),
    );
    final Uri? uri = artUri;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: uri == null
          ? placeholder
          : Image.network(
              uri.toString(),
              width: _size,
              height: _size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

class _QueueSectionLabel extends StatelessWidget {
  const _QueueSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white54,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    super.key,
    required this.item,
    required this.isCurrent,
    this.dimmed = false,
    this.trailing,
    this.onTap,
  });

  final MediaItem item;
  final bool isCurrent;
  final bool dimmed;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final double opacity = dimmed ? 0.5 : 1.0;
    return Opacity(
      opacity: opacity,
      child: ListTile(
        leading: isCurrent
            ? Icon(Icons.equalizer, color: Theme.of(context).colorScheme.primary)
            : _QueueRowArt(artUri: item.artUri),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: isCurrent ? FontWeight.w600 : null),
        ),
        subtitle: item.artist == null
            ? null
            : Text(item.artist!, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}

/// Sectioned queue sheet (NOWPLAYING.md NP9): items before the current one
/// render dimmed with no section header ("earlier" — cheaper than a third
/// "History" section per the plan); the current item gets its own
/// non-reorderable, non-dismissible "Now Playing" row; everything after it
/// is "Next Up" — the only slice that's actually reorderable/dismissible,
/// via [SliverReorderableList] (the same primitive `ReorderableListView`
/// wraps) so it can sit in a [CustomScrollView] alongside the earlier/
/// current sections without nesting one scrollable inside another.
///
/// Index mapping: the reorderable sub-list is 0-based over `nextUp`: a
/// local index [i] maps to the real audio-handler queue index via
/// `currentIndex + 1 + i`. `onReorderItem` (not the deprecated `onReorder`)
/// already reports the final target index with no further off-by-one
/// adjustment — verified by `now_playing_screen_test.dart`'s reorder test.
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
        final int foundIndex =
            items.indexWhere((MediaItem m) => m.id == currentId);
        final int currentIndex = foundIndex < 0 ? 0 : foundIndex;
        final List<MediaItem> earlier = items.sublist(0, currentIndex);
        final MediaItem nowPlaying = items[currentIndex];
        final List<MediaItem> nextUp = items.sublist(currentIndex + 1);

        return CustomScrollView(
          slivers: <Widget>[
            if (earlier.isNotEmpty)
              SliverList.builder(
                itemCount: earlier.length,
                itemBuilder: (BuildContext c, int i) => _QueueRow(
                  key: ValueKey<String>('queue-earlier-$i-${earlier[i].id}'),
                  item: earlier[i],
                  isCurrent: false,
                  dimmed: true,
                  onTap: () =>
                      ref.read(audioHandlerProvider).skipToQueueItem(i),
                ),
              ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _QueueSectionLabel('NOW PLAYING'),
                  _QueueRow(item: nowPlaying, isCurrent: true),
                  if (nextUp.isNotEmpty) const _QueueSectionLabel('NEXT UP'),
                ],
              ),
            ),
            if (nextUp.isNotEmpty)
              SliverReorderableList(
                itemCount: nextUp.length,
                onReorderItem: (int oldIndex, int newIndex) {
                  final int from = currentIndex + 1 + oldIndex;
                  final int to = currentIndex + 1 + newIndex;
                  ref.read(audioHandlerProvider).moveQueueItem(from, to);
                },
                itemBuilder: (BuildContext c, int i) {
                  final MediaItem m = nextUp[i];
                  final int realIndex = currentIndex + 1 + i;
                  // SliverReorderableList (unlike ReorderableListView) hoists
                  // the dragged item into the ambient Overlay without its
                  // own Material wrapper — give each row its own so the
                  // drag-proxy ListTile always has a Material ancestor.
                  return Material(
                    key: ValueKey<String>('queue-row-$realIndex-${m.id}'),
                    type: MaterialType.transparency,
                    child: Dismissible(
                      key: ValueKey<String>(
                          'queue-dismiss-$realIndex-${m.id}'),
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
                      onDismissed: (_) => ref
                          .read(audioHandlerProvider)
                          .removeQueueItemAt(realIndex),
                      child: _QueueRow(
                        item: m,
                        isCurrent: false,
                        trailing: ReorderableDragStartListener(
                          index: i,
                          child: const Icon(Icons.drag_handle),
                        ),
                        onTap: () => ref
                            .read(audioHandlerProvider)
                            .skipToQueueItem(realIndex),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
