import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recommend_health.dart';
import '../offline/offline_manifest.dart';
import '../offline/offline_paths.dart';
import '../offline/offline_settings.dart';
import '../offline/offline_size_estimator.dart';
import '../offline/offline_sync.dart';
import '../providers/recommendations.dart';
import '../providers/server_creds.dart';
import '../theme.dart';
import '../widgets/error_snackbar.dart';
import 'settings/profiles_section.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh recommendation-engine health when the screen opens. The
    // notifier no-ops when the cached payload is < 60 s old, so rapid
    // open/close cycles don't thrash the backend.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(recommendHealthNotifierProvider.notifier).refreshIfStale();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      // A1: the legacy "Servers" tile + screen are gone. Profiles are the
      // single credential surface — added via /login (Phase S) and managed
      // in ProfilesSection.
      body: ListView(
        children: const <Widget>[
          ProfilesSection(),
          Divider(),
          _OfflineSection(),
          Divider(),
          _RecommendationsSection(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recommendations health (N5)
// ---------------------------------------------------------------------------

class _RecommendationsSection extends ConsumerStatefulWidget {
  const _RecommendationsSection();

  @override
  ConsumerState<_RecommendationsSection> createState() =>
      _RecommendationsSectionState();
}

class _RecommendationsSectionState
    extends ConsumerState<_RecommendationsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<RecommendHealth> async =
        ref.watch(recommendHealthNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'Recommendations',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        async.when(
          loading: () => const ListTile(
            leading: Icon(Icons.recommend_outlined),
            title: Text('Engine health'),
            subtitle: Text('Checking…'),
          ),
          error: (Object e, _) => ListTile(
            leading: const Icon(Icons.recommend_outlined),
            title: const Text('Engine health'),
            subtitle: Text(
              'Could not reach backend — check token in Servers.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          data: (RecommendHealth h) {
            final bool degraded = h.status != 'ok';
            return Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.recommend_outlined),
                  title: Text('Engine: ${h.engine}'),
                  subtitle: Row(
                    children: <Widget>[
                      _StatusChip(degraded: degraded),
                      if (h.fallbackActive) ...<Widget>[
                        const SizedBox(width: 8),
                        const _FallbackBadge(),
                      ],
                    ],
                  ),
                  trailing: degraded
                      ? IconButton(
                          key: const Key('settings-recommend-help'),
                          icon: Icon(
                            _expanded
                                ? Icons.expand_less
                                : Icons.help_outline,
                          ),
                          tooltip: 'Why is this degraded?',
                          onPressed: () => setState(() {
                            _expanded = !_expanded;
                          }),
                        )
                      : null,
                ),
                if (degraded && _expanded)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
                    child: Text(
                      h.fallbackActive
                          ? 'Primary engine probe failed; '
                              'recommendations are running on the fallback. '
                              'Check your API key (Last.fm / ListenBrainz) '
                              'or wait for the upstream service to recover.'
                          : 'No engine in the chain is reachable. Check '
                              'the backend logs and your credentials.',
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.degraded});

  final bool degraded;

  @override
  Widget build(BuildContext context) {
    final Color colour = degraded ? Colors.amber : heerrGreen;
    return Chip(
      key: Key(degraded ? 'engine-chip-degraded' : 'engine-chip-ok'),
      avatar: Icon(
        degraded ? Icons.warning_amber_outlined : Icons.check_circle_outline,
        color: colour,
        size: 18,
      ),
      label: Text(
        degraded ? 'Degraded' : 'OK',
        style: TextStyle(color: colour, fontWeight: FontWeight.w500),
      ),
      backgroundColor: colour.withValues(alpha: 0.12),
      side: BorderSide(color: colour.withValues(alpha: 0.4)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _FallbackBadge extends StatelessWidget {
  const _FallbackBadge();

  @override
  Widget build(BuildContext context) {
    return Chip(
      key: const Key('engine-chip-fallback-active'),
      avatar: const Icon(Icons.shuffle, size: 16),
      label: const Text('Fallback active'),
      backgroundColor:
          Theme.of(context).colorScheme.surfaceContainerHighest,
      visualDensity: VisualDensity.compact,
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
          chargingOnly: false,
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
