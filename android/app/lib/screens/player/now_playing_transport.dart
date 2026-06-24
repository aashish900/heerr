part of 'now_playing_screen.dart';

class _Scrubber extends StatelessWidget {
  const _Scrubber({
    required this.position,
    required this.duration,
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeekStart;
  final ValueChanged<Duration> onSeekUpdate;
  final ValueChanged<Duration> onSeekEnd;

  @override
  Widget build(BuildContext context) {
    final double max = duration.inMilliseconds.toDouble();
    final double clampedPos =
        position.inMilliseconds.clamp(0, max <= 0 ? 0 : max.toInt()).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: <Widget>[
          Slider(
            value: max <= 0 ? 0 : clampedPos,
            max: max <= 0 ? 1 : max,
            onChangeStart: max <= 0
                ? null
                : (double v) =>
                    onSeekStart(Duration(milliseconds: v.toInt())),
            onChanged: max <= 0
                ? null
                : (double v) =>
                    onSeekUpdate(Duration(milliseconds: v.toInt())),
            onChangeEnd: max <= 0
                ? null
                : (double v) =>
                    onSeekEnd(Duration(milliseconds: v.toInt())),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(_fmt(position),
                    style: Theme.of(context).textTheme.bodySmall),
                Text(_fmt(duration),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final int total = d.inSeconds;
    final int m = total ~/ 60;
    final int s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
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
    final Color primary = Theme.of(context).colorScheme.primary;
    final bool shuffleOn = shuffleMode != AudioServiceShuffleMode.none;
    final bool repeatOn = repeatMode != AudioServiceRepeatMode.none;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        IconButton(
          iconSize: 28,
          tooltip: shuffleOn ? 'Shuffle on' : 'Shuffle off',
          color: shuffleOn ? primary : null,
          icon: const Icon(Icons.shuffle_rounded),
          onPressed: () {
            final HeerrAudioHandler h = ref.read(audioHandlerProvider);
            h.setShuffleMode(shuffleOn
                ? AudioServiceShuffleMode.none
                : AudioServiceShuffleMode.all);
          },
        ),
        IconButton(
          iconSize: 36,
          tooltip: 'Previous',
          icon: const Icon(Icons.skip_previous_rounded),
          onPressed: () => ref.read(audioHandlerProvider).skipToPrevious(),
        ),
        IconButton(
          iconSize: 56,
          tooltip: playing ? 'Pause' : 'Play',
          icon: Icon(
            playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
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
        IconButton(
          iconSize: 36,
          tooltip: 'Next',
          icon: const Icon(Icons.skip_next_rounded),
          onPressed: () => ref.read(audioHandlerProvider).skipToNext(),
        ),
        IconButton(
          iconSize: 28,
          tooltip: repeatMode == AudioServiceRepeatMode.one
              ? 'Repeat one'
              : repeatOn
                  ? 'Repeat all'
                  : 'Repeat off',
          color: repeatOn ? primary : null,
          icon: Icon(repeatMode == AudioServiceRepeatMode.one
              ? Icons.repeat_one_rounded
              : Icons.repeat_rounded),
          onPressed: () => ref
              .read(audioHandlerProvider)
              .setRepeatMode(_nextRepeat(repeatMode)),
        ),
      ],
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
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (BuildContext c, int i) {
            final MediaItem m = items[i];
            final bool isCurrent = m.id == currentId;
            return ListTile(
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
              onTap: () =>
                  ref.read(audioHandlerProvider).skipToQueueItem(i),
            );
          },
        );
      },
    );
  }
}
