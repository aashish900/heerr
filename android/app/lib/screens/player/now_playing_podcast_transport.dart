part of 'now_playing_screen.dart';

/// PR2 (#53): podcast-flavored player pieces, mirroring the music
/// equivalents (`now_playing_transport.dart` / `now_playing_action_pill.dart`)
/// but distinct where the design calls for it — a plain scrubber instead of
/// a waveform, skip±30s instead of prev/next track, and a speed picker in
/// place of shuffle/repeat/lyrics/add-to-playlist (none of which apply to a
/// single-episode "queue"). Chapters/Transcript/Notes/Bookmark and the
/// show's "Related" tab are explicitly out of scope — see the plan's scope
/// decisions (backend/DB carry none of that data).

/// Plain position/duration scrubber — a stock [Slider], not
/// [WaveformSeekBar]. The design's animated waveform has no backing
/// amplitude data for podcast audio, so this deliberately does not try to
/// visually match the music scrubber.
class _PodcastScrubber extends StatelessWidget {
  const _PodcastScrubber({
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
    final double totalMs = duration.inMilliseconds.toDouble();
    final double posMs =
        position.inMilliseconds.toDouble().clamp(0, totalMs == 0 ? 1 : totalMs);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: <Widget>[
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: heerrMagenta,
              inactiveTrackColor: Colors.white24,
              thumbColor: heerrMagenta,
            ),
            child: Slider(
              key: const Key('now-playing-podcast-scrubber'),
              min: 0,
              max: totalMs == 0 ? 1 : totalMs,
              value: posMs,
              onChangeStart: (double v) =>
                  onSeekStart(Duration(milliseconds: v.round())),
              onChanged: (double v) =>
                  onSeekUpdate(Duration(milliseconds: v.round())),
              onChangeEnd: (double v) =>
                  onSeekEnd(Duration(milliseconds: v.round())),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(_fmt(position), style: const TextStyle(color: Colors.white70)),
                Text(_fmt(duration), style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final int h = d.inHours;
    final int m = d.inMinutes.remainder(60);
    final int s = d.inSeconds.remainder(60);
    final String mm = h > 0 ? m.toString().padLeft(2, '0') : m.toString();
    final String ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }
}

/// Skip-back-30 / play-pause / skip-forward-30 — the design's podcast
/// transport, replacing prev/next track (a single episode has no
/// meaningful "next track" the way a music queue does).
class _PodcastTransport extends ConsumerWidget {
  const _PodcastTransport({required this.playing});

  final bool playing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        _TapScale(
          child: IconButton(
            key: const Key('now-playing-podcast-skip-back'),
            iconSize: 36,
            tooltip: 'Back 30 seconds',
            icon: const Icon(Icons.replay_30_rounded),
            onPressed: () => ref.read(audioHandlerProvider).skipBack30(),
          ),
        ),
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
            key: const Key('now-playing-podcast-skip-forward'),
            iconSize: 36,
            tooltip: 'Forward 30 seconds',
            icon: const Icon(Icons.forward_30_rounded),
            onPressed: () => ref.read(audioHandlerProvider).skipForward30(),
          ),
        ),
      ],
    );
  }
}

const List<double> kPodcastSpeeds = <double>[1.0, 1.25, 1.5, 1.75, 2.0];

String formatPodcastSpeed(double speed) {
  final bool whole = speed == speed.roundToDouble();
  return whole ? '${speed.toStringAsFixed(0)}x' : '${speed}x';
}

/// Queue / Speed / Timer — the podcast counterpart of [_ActionPill].
/// Lyrics and Add to playlist are dropped: neither applies to a
/// single-episode queue.
class _PodcastActionPill extends StatelessWidget {
  const _PodcastActionPill({
    required this.onQueueTap,
    required this.onSpeedTap,
    required this.onTimerTap,
    required this.speed,
    required this.sleepRemaining,
  });

  final VoidCallback onQueueTap;
  final VoidCallback onSpeedTap;
  final VoidCallback onTimerTap;
  final double speed;
  final Duration? sleepRemaining;

  @override
  Widget build(BuildContext context) {
    final Duration? remaining = sleepRemaining;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _PillSlot(
                  key: const Key('now-playing-queue-button'),
                  icon: Icons.queue_music_rounded,
                  label: 'Queue',
                  onTap: onQueueTap,
                ),
              ),
              const _PillDivider(),
              Expanded(
                child: _PillSlot(
                  key: const Key('now-playing-podcast-speed'),
                  icon: Icons.speed_rounded,
                  label: formatPodcastSpeed(speed),
                  onTap: onSpeedTap,
                ),
              ),
              const _PillDivider(),
              Expanded(
                child: remaining != null
                    ? _SleepCountdownChip(remaining: remaining)
                    : _PillSlot(
                        key: const Key('now-playing-pill-timer'),
                        icon: Icons.bedtime_outlined,
                        label: 'Timer',
                        onTap: onTimerTap,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Speed-picker bottom sheet — same visual language as [_SleepTimerSheet].
class _SpeedPickerSheet extends ConsumerWidget {
  const _SpeedPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double current =
        ref.watch(playerSnapshotProvider).valueOrNull?.state.speed ?? 1.0;

    void apply(double speed) {
      ref.read(audioHandlerProvider).setSpeed(speed);
      Navigator.of(context).pop();
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Playback speed',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final double speed in kPodcastSpeeds)
              ListTile(
                key: Key('now-playing-speed-${formatPodcastSpeed(speed)}'),
                leading: Icon(
                  speed == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: speed == current ? heerrMagenta : null,
                ),
                title: Text(formatPodcastSpeed(speed)),
                onTap: () => apply(speed),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tappable show-name link under the episode title — resolves the show's
/// title from [podcastSubscriptionsProvider] by `channelId` (the same
/// per-user subscription list already used across the podcast screens) and
/// pushes the show detail route on tap. `GoRouter.maybeOf` so widget tests
/// without a router ancestor don't crash (same fail-soft pattern used
/// elsewhere in the app, e.g. `library_tabs.dart::_onCreatePressed`).
class _PodcastShowLink extends ConsumerWidget {
  const _PodcastShowLink({required this.channelId});

  final String channelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<PodcastChannel>? subscriptions =
        ref.watch(podcastSubscriptionsProvider).valueOrNull;
    String title = 'Podcast';
    if (subscriptions != null) {
      for (final PodcastChannel c in subscriptions) {
        if (c.id == channelId) {
          title = c.title;
          break;
        }
      }
    }
    return InkWell(
      onTap: () {
        final GoRouter? router = GoRouter.maybeOf(context);
        router?.push(Routes.podcastsChannel(channelId));
      },
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(color: heerrMagenta),
      ),
    );
  }
}
