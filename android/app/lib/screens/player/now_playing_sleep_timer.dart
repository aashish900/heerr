part of 'now_playing_screen.dart';

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
