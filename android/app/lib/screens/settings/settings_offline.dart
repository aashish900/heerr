part of 'settings_screen.dart';

// ---------------------------------------------------------------------------
// Offline downloads section (Phase L)
// ---------------------------------------------------------------------------

const List<int> _kPollChoices = <int>[5, 15, 30, 60];

class _OfflineSection extends ConsumerWidget {
  const _OfflineSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<OfflineSettingsValue> async =
        ref.watch(offlineSettingsProvider);
    final OfflineSettingsValue s = async.valueOrNull ??
        (
          enabled: false,
          syncAll: false,
          wifiOnly: true,
          pollIntervalMinutes: 15,
          chargingOnly: false,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SwitchListTile(
          secondary: const DownloadIcon(filled: false),
          title: const Text('Offline downloads'),
          subtitle: const Text(
            'Marked albums and playlists download to the device. '
            'Playback uses the local file when available.',
          ),
          value: s.enabled,
          onChanged: (bool v) =>
              ref.read(offlineSettingsProvider.notifier).setEnabled(v),
        ),
        // Sub-controls greyed out when master is off.
        Opacity(
          opacity: s.enabled ? 1.0 : 0.5,
          child: AbsorbPointer(
            absorbing: !s.enabled,
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  title: const Text('WiFi only'),
                  subtitle: const Text(
                    'Pause syncing on cellular data.',
                  ),
                  value: s.wifiOnly,
                  onChanged: (bool v) => ref
                      .read(offlineSettingsProvider.notifier)
                      .setWifiOnly(v),
                ),
                // Q2: gates the WorkManager periodic worker on charger state.
                // Foreground sync ignores this — running while the user has
                // the app open should never be blocked.
                SwitchListTile(
                  title: const Text('Charging only'),
                  subtitle: const Text(
                    'Only run background sync while plugged in.',
                  ),
                  value: s.chargingOnly,
                  onChanged: (bool v) => ref
                      .read(offlineSettingsProvider.notifier)
                      .setChargingOnly(v),
                ),
                _SyncAllTile(syncAll: s.syncAll),
                ListTile(
                  title: const Text('Sync interval'),
                  subtitle: const Text(
                    'How often the app checks for new tracks while open.',
                  ),
                  trailing: DropdownButton<int>(
                    value: s.pollIntervalMinutes,
                    onChanged: (int? v) {
                      if (v == null) return;
                      ref
                          .read(offlineSettingsProvider.notifier)
                          .setPollInterval(v);
                    },
                    items: <DropdownMenuItem<int>>[
                      for (final int v in _kPollChoices)
                        DropdownMenuItem<int>(
                          value: v,
                          child: Text('$v min'),
                        ),
                    ],
                  ),
                ),
                const _StorageLine(),
                const _ClearAllAction(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StorageLine extends ConsumerWidget {
  const _StorageLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OfflineManifest? m =
        ref.watch(offlineManifestProvider).valueOrNull;
    if (m == null) {
      return const ListTile(
        leading: Icon(Icons.storage_outlined),
        title: Text('Local storage'),
        subtitle: Text('—'),
      );
    }
    final int totalBytes = m.songs.values
        .map((OfflineSongEntry e) => e.size ?? 0)
        .fold<int>(0, (int a, int b) => a + b);
    final String sizeStr = _humanBytes(totalBytes);
    return ListTile(
      leading: const Icon(Icons.storage_outlined),
      title: const Text('Local storage'),
      subtitle: Text(
        '${m.markedAlbums.length} albums · '
        '${m.markedPlaylists.length} playlists · '
        '${m.songs.length} songs · $sizeStr',
      ),
    );
  }
}

class _ClearAllAction extends ConsumerStatefulWidget {
  const _ClearAllAction();
  @override
  ConsumerState<_ClearAllAction> createState() => _ClearAllActionState();
}

class _ClearAllActionState extends ConsumerState<_ClearAllAction> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: <Widget>[
          TextButton.icon(
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.redAccent,
            ),
            label: const Text(
              'Clear all downloads',
              style: TextStyle(color: Colors.redAccent),
            ),
            onPressed: _busy ? null : _confirm,
          ),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Clear all downloads?'),
        content: const Text(
          'Removes every locally stored audio file and resets the offline '
          'manifest. Markers are cleared too — the next sync starts fresh.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final OfflinePaths paths =
          await ref.read(offlinePathsProvider.future);
      final ServerCreds settings = ref.read(serverCredsProvider);
      final Directory? serverRoot = paths.serverRoot(settings);
      if (serverRoot != null && await serverRoot.exists()) {
        await serverRoot.delete(recursive: true);
      }
      ref.invalidate(offlineManifestProvider);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
        duration: kSnackBarDuration,
        content: Text('Cleared all offline downloads.'),
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        duration: kSnackBarErrorDuration,
        content: Text('Failed to clear: $e'),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// "Sync entire library" toggle (L4). Subtitle shows the preflight estimate
/// from [offlineSizeEstimateProvider]. OFF → ON opens a confirmation dialog
/// quoting the size; cancel keeps the switch off; confirm flips it.
class _SyncAllTile extends ConsumerWidget {
  const _SyncAllTile({required this.syncAll});

  final bool syncAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<int?> estimate = ref.watch(offlineSizeEstimateProvider);
    return SwitchListTile(
      title: const Text('Sync entire library'),
      subtitle: Text(_subtitleFor(estimate)),
      value: syncAll,
      onChanged: (bool v) async {
        if (v) {
          await _confirmAndEnable(context, ref, estimate);
        } else {
          await ref.read(offlineSettingsProvider.notifier).setSyncAll(false);
        }
      },
    );
  }

  String _subtitleFor(AsyncValue<int?> estimate) {
    return estimate.when(
      loading: () => 'Calculating…',
      error: (Object _, StackTrace _) => 'Size unknown',
      data: (int? v) => v == null ? 'Size unknown' : '≈ ${_humanBytes(v)}',
    );
  }

  Future<void> _confirmAndEnable(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<int?> estimate,
  ) async {
    final int? size = estimate.valueOrNull;
    final String sizeStr = size == null ? 'the entire library' : _humanBytes(size);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Sync entire library?'),
        content: Text(
          'This will download ~$sizeStr and may take a while. Continue?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sync'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(offlineSettingsProvider.notifier).setSyncAll(true);
  }
}

String _humanBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
