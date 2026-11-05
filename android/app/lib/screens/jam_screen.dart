import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_error.dart';
import '../providers/jam_host.dart';
import '../providers/jam_remote.dart';
import '../theme.dart';
import '../widgets/error_snackbar.dart';

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

/// Guest view. The host's now-playing renders in the normal Now Playing
/// screen + mini-player (see `player/jam_display.dart`), whose controls drive
/// the host while joined; this page only reports the link and leaves it.
class _Joined extends ConsumerWidget {
  const _Joined(this.remote);

  final JamRemoteStatus remote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme tt = Theme.of(context).textTheme;
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Icon(Icons.settings_remote, size: 64, color: heerrMagenta),
        const SizedBox(height: 16),
        Text(
          "Controlling ${remote.hostUsername}'s phone",
          style: tt.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Play and Add to queue anywhere in heerr go to '
          '${remote.hostUsername}. Now Playing shows and controls their '
          'phone.',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const Key('jam-open-player'),
          onPressed: () => context.push('/player'),
          icon: const Icon(Icons.music_note),
          label: const Text('Open Now Playing'),
        ),
        const Spacer(),
        OutlinedButton.icon(
          key: const Key('jam-leave'),
          onPressed: () => ref.read(jamRemoteProvider.notifier).leave(),
          icon: const Icon(Icons.logout),
          label: const Text('Leave session'),
        ),
      ],
    );
  }
}
