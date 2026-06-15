import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_error.dart';
import '../../models/subsonic/lyrics.dart';
import '../../player/heerr_audio_handler.dart';
import '../../player/player_provider.dart';
import '../../player/sleep_timer.dart';
import '../../providers/library/lyrics.dart';
import '../../providers/queue.dart';
import '../../utils/palette.dart';

/// Injection point for tests — swap `dominantColorFor` with a deterministic
/// fake (e.g. `(_) async => Colors.purple`) so widget tests don't hit the
/// network and don't depend on `package:palette_generator`'s decode path.
typedef PaletteExtractor = Future<Color?> Function(Uri? artUri);

@visibleForTesting
PaletteExtractor paletteExtractorOverride = dominantColorFor;

/// Full-screen Now Playing surface. Cover art on top, title/artist, scrubber
/// bound to the live position, transport controls, and the queue list at the
/// bottom.
///
/// State sources:
///   * [playerSnapshotProvider] — current `MediaItem` + `PlaybackState` (the
///     `playing` flag, the projected position, the duration via item).
///   * [playerQueueProvider] — queue list for the bottom section.
///
/// Position ticker: PlaybackState only emits on state changes (play, pause,
/// seek, buffer). To keep the scrubber smooth between events we rebuild every
/// 250ms via a private `Stream.periodic` while playing. The position is read
/// from the snapshot's `state.position` getter, which already extrapolates
/// from `updatePosition + elapsed * speed` (see PlaybackState in audio_service).
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  Timer? _ticker;
  Duration? _scrubOverride;

  // Cover-art-derived tint colour. Recomputed when the current MediaItem's
  // artUri changes. Null while loading or when extraction fails — the body
  // falls back to the default surface in that case.
  Uri? _tintArtUri;
  Color? _tintColor;

  // P2: lyrics view toggle. Persisted as widget state — survives screen
  // rebuilds but resets on Now Playing pop / push (intentional; lyrics is
  // a per-session view choice, not a global preference).
  bool _showLyrics = false;

  // Cached queue notifier so dispose() doesn't have to read it through `ref`
  // (Riverpod invalidates the ref before State.dispose runs — caching here
  // means resume() can fire even during teardown).
  Queue? _queueNotifier;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
    // K1 lifecycle: pause the /queue poller while Now Playing is foreground.
    // The queue + reactive-promotion logic stays paused; the user can't see
    // it from here. Resumed in dispose().
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final Queue q = ref.read(queueProvider.notifier);
        _queueNotifier = q;
        q.pause();
      } catch (_) {
        // Provider may not be initialised yet (rare); ignore.
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    // Use the cached notifier so we don't have to touch `ref` — Riverpod
    // invalidates it before this dispose runs.
    try {
      _queueNotifier?.resume();
    } catch (_) {
      // Notifier may already be disposed; ignore.
    }
    super.dispose();
  }

  void _openSleepTimerSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => const _SleepTimerSheet(),
    );
  }

  void _maybeRefreshTint(Uri? artUri) {
    if (artUri == _tintArtUri) return;
    _tintArtUri = artUri;
    final Uri? captured = artUri;
    paletteExtractorOverride(captured).then((Color? c) {
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

    final Duration? sleepRemaining = ref.watch(sleepTimerNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Now playing'),
        backgroundColor: _tintColor?.withValues(alpha: 0.6),
        actions: <Widget>[
          if (sleepRemaining != null)
            _SleepCountdownChip(remaining: sleepRemaining),
          IconButton(
            key: const Key('now-playing-lyrics-toggle'),
            tooltip: _showLyrics ? 'Show cover art' : 'Show lyrics',
            icon: Icon(
              _showLyrics ? Icons.image_outlined : Icons.lyrics_outlined,
            ),
            onPressed: () => setState(() => _showLyrics = !_showLyrics),
          ),
          PopupMenuButton<String>(
            key: const Key('now-playing-overflow'),
            tooltip: 'More',
            icon: const Icon(Icons.more_vert),
            onSelected: (String v) {
              if (v == 'sleep') {
                _openSleepTimerSheet(context);
              }
            },
            itemBuilder: (BuildContext _) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'sleep',
                child: Text('Sleep timer'),
              ),
            ],
          ),
        ],
      ),
      body: snap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('Player error: $e')),
        data: (PlayerSnapshot s) {
          final MediaItem? item = s.item;
          if (item == null) {
            _maybeRefreshTint(null);
            return const Center(child: Text('Nothing is playing.'));
          }
          _maybeRefreshTint(item.artUri);
          return _TintedBackground(
            color: _tintColor,
            child: _Body(
              snapshot: s,
              showLyrics: _showLyrics,
              scrubOverride: _scrubOverride,
              onSeekStart: (Duration d) => setState(() => _scrubOverride = d),
              onSeekUpdate: (Duration d) => setState(() => _scrubOverride = d),
              onSeekEnd: (Duration d) {
                ref.read(audioHandlerProvider).seek(d);
                setState(() => _scrubOverride = null);
              },
            ),
          );
        },
      ),
    );
  }
}

/// Vertical gradient from [color] (top, at low opacity) to the default M3
/// surface (bottom). Null [color] → no gradient applied.
class _TintedBackground extends StatelessWidget {
  const _TintedBackground({required this.color, required this.child});

  final Color? color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Color? c = color;
    if (c == null) return child;
    final ColorScheme cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            c.withValues(alpha: 0.45),
            cs.surface,
          ],
          stops: const <double>[0.0, 0.65],
        ),
      ),
      child: child,
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.snapshot,
    required this.showLyrics,
    required this.scrubOverride,
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
  });

  final PlayerSnapshot snapshot;
  final bool showLyrics;
  final Duration? scrubOverride;
  final ValueChanged<Duration> onSeekStart;
  final ValueChanged<Duration> onSeekUpdate;
  final ValueChanged<Duration> onSeekEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MediaItem item = snapshot.item!;
    final Duration duration = item.duration ?? Duration.zero;
    final Duration position = scrubOverride ?? snapshot.state.position;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 16),
        Center(
          child: showLyrics
              ? _LyricsPane(title: item.title, artist: item.artist)
              : _CoverArt(artUri: item.artUri),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                item.title,
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (item.artist != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  item.artist!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        _Scrubber(
          position: position,
          duration: duration,
          onSeekStart: onSeekStart,
          onSeekUpdate: onSeekUpdate,
          onSeekEnd: onSeekEnd,
        ),
        _Transport(playing: snapshot.isPlaying),
        const SizedBox(height: 8),
        const Divider(height: 1),
        const Expanded(child: _QueueList()),
      ],
    );
  }
}

class _CoverArt extends StatelessWidget {
  const _CoverArt({required this.artUri});

  final Uri? artUri;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Uri? uri = artUri;
    final Widget placeholder = Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.music_note, size: 96, color: cs.onSurfaceVariant),
    );
    if (uri == null) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        uri.toString(),
        width: 240,
        height: 240,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}

/// P2: scrollable lyrics pane shown in place of the cover art when the
/// user toggles the AppBar lyrics action. Sized to match the cover-art
/// box (240×240) so the surrounding scrubber + transport + queue don't
/// jump when switching views.
///
/// Render rules:
///  - `artist` or `title` empty → "No lyrics for this track" empty state.
///  - Provider loading → spinner.
///  - Provider error (any [ApiError]) → readable error line.
///  - Provider data null → "No lyrics for this track" empty state.
///  - Provider data → scrollable plain text with selectable copy.
class _LyricsPane extends ConsumerWidget {
  const _LyricsPane({required this.title, required this.artist});

  final String title;
  final String? artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? a = artist;
    if (a == null || a.isEmpty || title.isEmpty) {
      return const _LyricsBox(
        child: Center(
          key: Key('now-playing-lyrics-empty'),
          child: Text('No lyrics for this track'),
        ),
      );
    }
    final AsyncValue<Lyrics?> async = ref.watch(lyricsForProvider(a, title));
    return _LyricsBox(
      child: async.when(
        loading: () => const Center(
          key: Key('now-playing-lyrics-loading'),
          child: CircularProgressIndicator(),
        ),
        error: (Object e, _) => Center(
          key: const Key('now-playing-lyrics-error'),
          child: Text(
            e is ApiError ? e.message : 'Lyrics error: $e',
            textAlign: TextAlign.center,
          ),
        ),
        data: (Lyrics? lyrics) {
          final String? value = lyrics?.value;
          if (value == null || value.trim().isEmpty) {
            return const Center(
              key: Key('now-playing-lyrics-empty'),
              child: Text('No lyrics for this track'),
            );
          }
          return Scrollbar(
            child: SingleChildScrollView(
              key: const Key('now-playing-lyrics-scroll'),
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                value,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LyricsBox extends StatelessWidget {
  const _LyricsBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

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
  const _Transport({required this.playing});

  final bool playing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        IconButton(
          iconSize: 36,
          tooltip: 'Previous',
          icon: const Icon(Icons.skip_previous),
          onPressed: () => ref.read(audioHandlerProvider).skipToPrevious(),
        ),
        IconButton(
          iconSize: 56,
          tooltip: playing ? 'Pause' : 'Play',
          icon: Icon(
            playing
                ? Icons.pause_circle_filled
                : Icons.play_circle_fill,
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
          icon: const Icon(Icons.skip_next),
          onPressed: () => ref.read(audioHandlerProvider).skipToNext(),
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

/// P3: small AppBar chip showing remaining sleep-timer time as `MM:SS`
/// (or `H:MM:SS` for over an hour). Tapping reopens the bottom sheet so
/// the user can change or cancel without hunting in the overflow menu.
class _SleepCountdownChip extends ConsumerWidget {
  const _SleepCountdownChip({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: InputChip(
        key: const Key('now-playing-sleep-chip'),
        avatar: Icon(Icons.bedtime_outlined, size: 16, color: cs.primary),
        label: Text(_format(remaining)),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (BuildContext _) => const _SleepTimerSheet(),
        ),
      ),
    );
  }

  static String _format(Duration d) {
    final int total = d.inSeconds;
    final int h = total ~/ 3600;
    final int m = (total % 3600) ~/ 60;
    final int s = total % 60;
    final String mm = m.toString().padLeft(2, '0');
    final String ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }
}

/// P3: sleep-timer bottom sheet. Five preset options + "Custom…" + an
/// "Off" tile when a timer is active.
class _SleepTimerSheet extends ConsumerWidget {
  const _SleepTimerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Duration? active = ref.watch(sleepTimerNotifierProvider);

    void apply(Duration d) {
      ref.read(sleepTimerNotifierProvider.notifier).setDuration(d);
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
                'Sleep timer',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              key: const Key('sleep-timer-15'),
              leading: const Icon(Icons.bedtime_outlined),
              title: const Text('15 minutes'),
              onTap: () => apply(const Duration(minutes: 15)),
            ),
            ListTile(
              key: const Key('sleep-timer-30'),
              leading: const Icon(Icons.bedtime_outlined),
              title: const Text('30 minutes'),
              onTap: () => apply(const Duration(minutes: 30)),
            ),
            ListTile(
              key: const Key('sleep-timer-45'),
              leading: const Icon(Icons.bedtime_outlined),
              title: const Text('45 minutes'),
              onTap: () => apply(const Duration(minutes: 45)),
            ),
            ListTile(
              key: const Key('sleep-timer-60'),
              leading: const Icon(Icons.bedtime_outlined),
              title: const Text('1 hour'),
              onTap: () => apply(const Duration(hours: 1)),
            ),
            ListTile(
              key: const Key('sleep-timer-custom'),
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Custom…'),
              onTap: () async {
                final int? minutes =
                    await _CustomMinutesDialog.show(context);
                if (minutes == null || minutes <= 0) return;
                if (!context.mounted) return;
                apply(Duration(minutes: minutes));
              },
            ),
            if (active != null)
              ListTile(
                key: const Key('sleep-timer-off'),
                leading: const Icon(Icons.cancel_outlined),
                title: const Text('Off (cancel)'),
                onTap: () {
                  ref.read(sleepTimerNotifierProvider.notifier).cancel();
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// "Enter minutes" dialog for the custom sleep-timer option. Returns the
/// integer minute count, or null on cancel / invalid input.
class _CustomMinutesDialog extends StatefulWidget {
  const _CustomMinutesDialog();

  static Future<int?> show(BuildContext context) {
    return showDialog<int>(
      context: context,
      builder: (_) => const _CustomMinutesDialog(),
    );
  }

  @override
  State<_CustomMinutesDialog> createState() => _CustomMinutesDialogState();
}

class _CustomMinutesDialogState extends State<_CustomMinutesDialog> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom sleep timer'),
      content: TextField(
        key: const Key('sleep-timer-custom-field'),
        controller: _ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Minutes',
          hintText: 'e.g. 25',
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('sleep-timer-custom-confirm'),
          onPressed: () {
            final int? parsed = int.tryParse(_ctrl.text.trim());
            Navigator.of(context).pop(parsed);
          },
          child: const Text('Set'),
        ),
      ],
    );
  }
}
