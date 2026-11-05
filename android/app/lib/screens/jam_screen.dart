import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../models/subsonic/song.dart';
import '../providers/jam_host.dart';
import '../providers/jam_remote.dart';
import '../theme.dart';
import '../widgets/error_snackbar.dart';
import '../widgets/library_cover_art.dart';

/// Phase JM: host a jam session (guests control playback on this phone) or
/// join one (this phone becomes a remote for the host). Reached from
/// Settings -> Remote control.
class JamScreen extends ConsumerWidget {
  const JamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final JamHostStatus? host = ref.watch(jamHostProvider);
    final JamRemoteStatus? remote = ref.watch(jamRemoteProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Jam session')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: host != null
              ? _Hosting(host)
              : remote != null
              ? _Joined(remote)
              : const _Idle(),
        ),
      ),
    );
  }
}

class _Idle extends ConsumerStatefulWidget {
  const _Idle();

  @override
  ConsumerState<_Idle> createState() => _IdleState();
}

class _IdleState extends ConsumerState<_Idle> {
  bool _busy = false;
  final TextEditingController _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_code.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(jamRemoteProvider.notifier).join(_code.text);
    } on NotFoundError {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: kSnackBarErrorDuration,
            content: Text('No live session with that code.'),
          ),
        );
      }
    } on ApiError catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      await ref.read(jamHostProvider.notifier).start();
    } on ApiError catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Let a friend pick songs from their phone while this phone plays '
          'them (e.g. on Android Auto).',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const Key('jam-start'),
          onPressed: _busy ? null : _start,
          icon: const Icon(Icons.speaker_group),
          label: const Text('Start session (this phone plays)'),
        ),
        const SizedBox(height: 40),
        Text(
          'Or control a friend\'s phone',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('jam-code-field'),
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Session code',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _join(),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          key: const Key('jam-join'),
          onPressed: _busy ? null : _join,
          icon: const Icon(Icons.settings_remote),
          label: const Text('Join session'),
        ),
      ],
    );
  }
}

class _Hosting extends ConsumerWidget {
  const _Hosting(this.host);

  final JamHostStatus host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme tt = Theme.of(context).textTheme;
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Session code',
          style: tt.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        SelectableText(
          host.code,
          key: const Key('jam-code'),
          textAlign: TextAlign.center,
          style: tt.displayMedium?.copyWith(
            fontFamily: 'monospace',
            letterSpacing: 8,
            fontWeight: FontWeight.w700,
            color: heerrMagenta,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Guests open heerr -> Settings -> Jam session and type this code.',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Text(
          'Commands received: ${host.commandsReceived}',
          textAlign: TextAlign.center,
        ),
        if (host.error != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            'Reconnecting...',
            key: const Key('jam-reconnecting'),
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(color: cs.error),
          ),
        ],
        const Spacer(),
        OutlinedButton.icon(
          key: const Key('jam-stop'),
          onPressed: () => ref.read(jamHostProvider.notifier).stop(),
          icon: const Icon(Icons.stop),
          label: const Text('Stop session'),
        ),
      ],
    );
  }
}

/// Guest view: the host's now-playing + queue from the polled snapshot, and
/// transport buttons that send commands. Positions update with each 2s poll
/// (no client-side extrapolation: the host clock may differ from ours).
class _Joined extends ConsumerWidget {
  const _Joined(this.remote);

  final JamRemoteStatus remote;

  Future<void> _send(
    BuildContext context,
    WidgetRef ref,
    String kind, [
    Map<String, dynamic>? payload,
  ]) async {
    try {
      await ref.read(jamRemoteProvider.notifier).send(kind, payload);
    } on NotFoundError {
      ref.read(jamRemoteProvider.notifier).leave();
    } on ApiError catch (e) {
      if (context.mounted) showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme tt = Theme.of(context).textTheme;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Map<String, dynamic> s =
        remote.hostState?.state ?? const <String, dynamic>{};
    final Song? current = _song(s['current']);
    final bool playing = s['playing'] == true;
    final int positionMs = s['position_ms'] is int
        ? s['position_ms'] as int
        : 0;
    final int durationMs = (current?.duration ?? 0) * 1000;
    final List<Song> upNext = <Song>[
      if (s['queue'] is List)
        for (final dynamic e in (s['queue'] as List<dynamic>).skip(1).take(10))
          if (_song(e) case final Song song) song,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Controlling ${remote.hostUsername}\'s phone',
          style: tt.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Center(
          child: LibraryCoverArt(coverArtId: current?.coverArt, size: 160),
        ),
        const SizedBox(height: 12),
        Text(
          current?.title ?? 'Nothing playing',
          key: const Key('jam-now-title'),
          style: tt.titleLarge,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (current?.artist != null)
          Text(
            current!.artist!,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        if (durationMs > 0)
          _SeekBar(
            positionMs: positionMs.clamp(0, durationMs),
            durationMs: durationMs,
            onSeek: (int ms) => _send(context, ref, 'seek', <String, dynamic>{
              'position_ms': ms,
            }),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            IconButton(
              key: const Key('jam-prev'),
              iconSize: 36,
              icon: const Icon(Icons.skip_previous),
              onPressed: () => _send(context, ref, 'prev'),
            ),
            IconButton.filled(
              key: const Key('jam-playpause'),
              iconSize: 44,
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              onPressed: () => _send(context, ref, playing ? 'pause' : 'play'),
            ),
            IconButton(
              key: const Key('jam-next'),
              iconSize: 36,
              icon: const Icon(Icons.skip_next),
              onPressed: () => _send(context, ref, 'next'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Pick songs anywhere in heerr: Play and Add to queue go to '
          '${remote.hostUsername}.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        if (upNext.isNotEmpty) Text('Up next', style: tt.titleSmall),
        Expanded(
          child: ListView(
            children: <Widget>[
              for (final Song song in upNext)
                ListTile(
                  dense: true,
                  title: Text(song.title, maxLines: 1),
                  subtitle: song.artist == null ? null : Text(song.artist!),
                ),
            ],
          ),
        ),
        OutlinedButton.icon(
          key: const Key('jam-leave'),
          onPressed: () => ref.read(jamRemoteProvider.notifier).leave(),
          icon: const Icon(Icons.logout),
          label: const Text('Leave session'),
        ),
      ],
    );
  }

  static Song? _song(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    try {
      return Song.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}

/// Slider that follows the host position except while the user drags; the
/// seek is sent once on release.
class _SeekBar extends StatefulWidget {
  const _SeekBar({
    required this.positionMs,
    required this.durationMs,
    required this.onSeek,
  });

  final int positionMs;
  final int durationMs;
  final ValueChanged<int> onSeek;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    return Slider(
      key: const Key('jam-seek'),
      value: _drag ?? widget.positionMs.toDouble(),
      max: widget.durationMs.toDouble(),
      onChanged: (double v) => setState(() => _drag = v),
      onChangeEnd: (double v) {
        setState(() => _drag = null);
        widget.onSeek(v.round());
      },
    );
  }
}
