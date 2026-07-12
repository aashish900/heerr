import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../offline/offline_sync.dart';
import '../../providers/server_creds.dart';
import '../../providers/server_status.dart';
import '../../theme.dart';
import '../../widgets/waveform_strip.dart';
import 'server_glyph.dart';

/// Downloads "Sync Center" hero (DL2, DOWNLOADSSCREEN.md §2). Four states:
/// online+idle, online+syncing (animated waveform progress), offline, and
/// sync error. Reachability = backend `/health` only (D1) — the thin client
/// never pings Navidrome directly.
class ServerStatusCard extends ConsumerWidget {
  const ServerStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ServerGlyph(online: online),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        'Home Server',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(width: 8),
                      _StatusPill(online: online),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    online ? '$hostLabel • via Tailscale' : 'Server unreachable',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (syncing && sync != null)
                    _SyncProgress(sync: sync)
                  else
                    Text(
                      _idleCaption(sync, statusError),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                ],
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

  String _idleCaption(OfflineSyncStatus? sync, String? statusError) {
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.online});
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

class _SyncProgress extends StatelessWidget {
  const _SyncProgress({required this.sync});
  final OfflineSyncStatus sync;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final int remaining = (sync.targetCount - sync.readyCount).clamp(0, sync.targetCount);
    final double progress = sync.targetCount == 0 ? 0 : sync.readyCount / sync.targetCount;
    final int percent = (progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Syncing library',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        WaveformStrip(
          height: 28,
          gradient: heerrGradient,
          seed: 0,
          animate: true,
          progress: progress,
        ),
        const SizedBox(height: 6),
        Text(
          '$remaining song${remaining == 1 ? '' : 's'} remaining • $percent%',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
