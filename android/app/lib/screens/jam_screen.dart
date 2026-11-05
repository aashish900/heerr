import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../providers/jam_host.dart';
import '../theme.dart';
import '../widgets/error_snackbar.dart';

/// Phase JM: start / stop a jam session in which guests control playback on
/// this phone. Reached from Settings -> Remote control.
class JamScreen extends ConsumerWidget {
  const JamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final JamHostStatus? host = ref.watch(jamHostProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Jam session')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: host == null ? const _Idle() : _Hosting(host),
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
