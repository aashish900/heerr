part of 'settings_screen.dart';

// ---------------------------------------------------------------------------
// Downloads & Storage group (SETTINGSSCREEN.md SE5; originally Phase L)
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

    return SettingsGroupCard(
      children: <Widget>[
        SettingsSwitchTile(
          icon: Icons.download_outlined,
          title: 'Offline downloads',
          // D4: the sync sweep runs automatically (no standalone "Auto
          // Cleanup" toggle) — mentioned here instead.
          subtitle: 'Marked albums and playlists download to the device. '
              'Unmarked files are cleaned up automatically.',
          value: s.enabled,
          onChanged: (bool v) =>
              ref.read(offlineSettingsProvider.notifier).setEnabled(v),
        ),
        // Sub-controls greyed out when the master switch is off. D6: Wi-Fi
        // only / Charging only / Sync interval live here, not on the
        // promoted Server & Sync card (SE4) — they gate downloading, not
        // connectivity.
        Opacity(
          opacity: s.enabled ? 1.0 : 0.5,
          child: AbsorbPointer(
            absorbing: !s.enabled,
            child: Column(
              children: <Widget>[
                SettingsSwitchTile(
                  icon: Icons.wifi,
                  title: 'WiFi only',
                  subtitle: 'Pause syncing on cellular data.',
                  value: s.wifiOnly,
                  onChanged: (bool v) => ref
                      .read(offlineSettingsProvider.notifier)
                      .setWifiOnly(v),
                ),
                // Q2: gates the WorkManager periodic worker on charger state.
                // Foreground sync ignores this — running while the user has
                // the app open should never be blocked.
                SettingsSwitchTile(
                  icon: Icons.battery_charging_full_outlined,
                  title: 'Charging only',
                  subtitle: 'Only run background sync while plugged in.',
                  value: s.chargingOnly,
                  onChanged: (bool v) => ref
                      .read(offlineSettingsProvider.notifier)
                      .setChargingOnly(v),
                ),
                _SyncAllTile(syncAll: s.syncAll),
                SettingsDropdownTile<int>(
                  icon: Icons.timer_outlined,
                  title: 'Sync interval',
                  subtitle: 'How often the app checks for new tracks while open.',
                  value: s.pollIntervalMinutes,
                  items: _kPollChoices,
                  labelBuilder: (int v) => '$v min',
                  onChanged: (int v) => ref
                      .read(offlineSettingsProvider.notifier)
                      .setPollInterval(v),
                ),
                const _StorageLine(),
                const _ClearAllTile(),
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
      return const SettingsTile(
        icon: Icons.storage_outlined,
        title: 'Local storage',
        subtitle: '—',
      );
    }
    final int totalBytes = m.songs.values
        .map((OfflineSongEntry e) => e.size ?? 0)
        .fold<int>(0, (int a, int b) => a + b);
    final String sizeStr = _humanBytes(totalBytes);
    return SettingsTile(
      icon: Icons.storage_outlined,
      title: 'Local storage',
      subtitle: '${m.markedAlbums.length} albums · '
          '${m.markedPlaylists.length} playlists · '
          '${m.songs.length} songs · $sizeStr',
    );
  }
}

class _ClearAllTile extends ConsumerStatefulWidget {
  const _ClearAllTile();
  @override
  ConsumerState<_ClearAllTile> createState() => _ClearAllTileState();
}

class _ClearAllTileState extends ConsumerState<_ClearAllTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      icon: Icons.delete_outline,
      title: 'Clear all downloads',
      iconColor: Colors.redAccent,
      titleColor: Colors.redAccent,
      onTap: _busy ? null : _confirm,
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
    // Pause the sync notifier so its own downloader can't drop a new file
    // into `serverRoot` mid-delete (below) — one of several concurrent
    // writers (cover art / library cache / lyrics caching also write here
    // whenever the user is browsing) that can race `Directory.delete`.
    ref.read(offlineSyncProvider.notifier).pause();
    try {
      final OfflinePaths paths =
          await ref.read(offlinePathsProvider.future);
      final ServerCreds settings = ref.read(serverCredsProvider);
      final Directory? serverRoot = paths.serverRoot(settings);
      if (serverRoot != null) {
        await deleteRecursiveWithRetry(serverRoot);
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
      if (mounted) {
        unawaited(ref.read(offlineSyncProvider.notifier).resume());
        setState(() => _busy = false);
      }
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
    return SettingsSwitchTile(
      icon: Icons.library_music_outlined,
      title: 'Sync entire library',
      subtitle: _subtitleFor(estimate),
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
