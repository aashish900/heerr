import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../offline/offline_sync.dart';
import '../../providers/server_creds.dart';
import '../../providers/server_status.dart';
import '../../theme.dart';
import '../../widgets/error_snackbar.dart';

/// Promoted "Server & Sync" card (SETTINGSSCREEN.md SE4, D3/D6). Visually one
/// step above the flat `SettingsGroupCard`s: hostname + Online/Offline pill
/// (reusing the `serverStatusNotifierProvider` poll and the same status-green
/// semantics as the Downloads hero), last-sync relative time, and an inline
/// Sync Now action (logic lifted from the old `_SyncNowAction`). Wi-Fi
/// only / Charging only / Sync interval stay in Downloads & Storage (D6) —
/// this card is status + action only.
class ServerSyncCard extends ConsumerStatefulWidget {
  const ServerSyncCard({super.key});

  @override
  ConsumerState<ServerSyncCard> createState() => _ServerSyncCardState();
}

class _ServerSyncCardState extends ConsumerState<ServerSyncCard> {
  bool _busy = false;

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
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          duration: kSnackBarDuration,
          content: Text(msg),
        ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ServerStatus> statusAsync =
        ref.watch(serverStatusNotifierProvider);
    final AsyncValue<OfflineSyncStatus> syncAsync =
        ref.watch(offlineSyncProvider);
    final ServerCreds creds = ref.watch(serverCredsProvider);

    final bool online = statusAsync.valueOrNull?.online ?? false;
    final String? statusError = statusAsync.valueOrNull?.errorMessage;
    final OfflineSyncStatus? sync = syncAsync.valueOrNull;
    final bool syncing = sync?.running ?? false;

    final String hostLabel = _hostLabel(creds.navidromeBaseUrl);
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: online ? heerrMagenta.withValues(alpha: 0.25) : Colors.white10,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.dns_outlined, color: heerrMagenta),
                const SizedBox(width: 12),
                Text(
                  'Home Server',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(width: 8),
                _OnlinePill(online: online),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              online ? '$hostLabel • via Tailscale' : 'Server unreachable',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              _syncCaption(sync, statusError, syncing),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: const Text('Sync now'),
                onPressed: _busy || syncing ? null : _runSync,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _hostLabel(String? navidromeBaseUrl) {
    if (navidromeBaseUrl == null || navidromeBaseUrl.isEmpty) return 'Navidrome';
    final Uri? uri = Uri.tryParse(navidromeBaseUrl);
    return uri?.host.isNotEmpty == true ? uri!.host : 'Navidrome';
  }

  String _syncCaption(OfflineSyncStatus? sync, String? statusError, bool syncing) {
    if (syncing) return 'Syncing…';
    if (statusError != null && statusError != 'No server configured') {
      return statusError;
    }
    final DateTime? lastTick = sync?.lastTickAt;
    if (lastTick == null) return 'Not synced yet';
    return 'Last synced ${_relativeTime(lastTick)}';
  }

  String _relativeTime(DateTime at) {
    final Duration d = DateTime.now().difference(at);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} hr ago';
    return '${d.inDays} d ago';
  }
}

/// Same visual + semantics as Downloads' `_StatusPill` (server_status_card.dart)
/// — status-only `heerrOnlineGreen`, not a new "subtle" indicator (D3).
class _OnlinePill extends StatelessWidget {
  const _OnlinePill({required this.online});
  final bool online;

  @override
  Widget build(BuildContext context) {
    final Color color = online ? heerrOnlineGreen : Colors.white38;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        online ? 'Online' : 'Offline',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
