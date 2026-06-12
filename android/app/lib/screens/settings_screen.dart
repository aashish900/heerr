import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../offline/offline_manifest.dart';
import '../offline/offline_paths.dart';
import '../offline/offline_settings.dart';
import '../offline/offline_sync.dart';
import '../providers/settings.dart';
import '../router.dart';
import '../widgets/error_snackbar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: const <Widget>[
          _OfflineSection(),
          Divider(),
          _ServersTile(),
        ],
      ),
    );
  }
}

class _ServersTile extends StatelessWidget {
  const _ServersTile();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.dns_outlined),
      title: const Text('Servers'),
      subtitle: const Text('Manage backend connections'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(Routes.servers),
    );
  }
}

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
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'Offline downloads',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.download_for_offline_outlined),
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
                const _SyncNowAction(),
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

class _SyncNowAction extends ConsumerStatefulWidget {
  const _SyncNowAction();
  @override
  ConsumerState<_SyncNowAction> createState() => _SyncNowActionState();
}

class _SyncNowActionState extends ConsumerState<_SyncNowAction> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: <Widget>[
          FilledButton.icon(
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: const Text('Sync now'),
            onPressed: _busy ? null : _runSync,
          ),
        ],
      ),
    );
  }

  Future<void> _runSync() async {
    setState(() => _busy = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(const SnackBar(
        duration: kSnackBarDuration,
        content: Text('Syncing…'),
      ));
      final OfflineSyncResult r =
          await ref.read(offlineSyncProvider.notifier).syncNow();
      if (!mounted) return;
      final String msg;
      if (r.error != null) {
        msg = 'Sync: ${r.error}';
      } else {
        final List<String> parts = <String>[];
        if (r.downloadedCount > 0) parts.add('${r.downloadedCount} downloaded');
        if (r.failedCount > 0) parts.add('${r.failedCount} failed');
        if (r.sweptCount > 0) parts.add('${r.sweptCount} cleaned up');
        msg = parts.isEmpty ? 'Nothing to do.' : 'Synced: ${parts.join(', ')}';
      }
      messenger.showSnackBar(SnackBar(
        duration: kSnackBarDuration,
        content: Text(msg),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
      final SettingsValue settings =
          await ref.read(settingsProvider.future);
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

String _humanBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
