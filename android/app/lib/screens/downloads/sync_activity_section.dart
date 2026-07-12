import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/sync_activity.dart';
import '../../theme.dart';
import '../../widgets/waveform_strip.dart';

/// Downloads "Sync Center" activity row (DL4, DOWNLOADSSCREEN.md §3): up to
/// three compact cards — Downloading, Queued, and a third slot that shows
/// "Waiting for Wi-Fi" when the Wi-Fi-only gate is holding work back, or
/// Failed otherwise. Hidden entirely when there's nothing to report.
class SyncActivitySection extends ConsumerWidget {
  const SyncActivitySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SyncActivity? a = ref.watch(syncActivityProvider).valueOrNull;
    if (a == null) return const SizedBox.shrink();

    final List<Widget> cards = <Widget>[];
    if (a.downloadingCount > 0) {
      cards.add(_ActivityCard(
        icon: Icons.downloading_outlined,
        label: 'Downloading',
        value: '${a.downloadingCount} song${a.downloadingCount == 1 ? '' : 's'}',
        animateWaveform: true,
      ));
    }
    if (a.queuedCount > 0) {
      cards.add(_ActivityCard(
        icon: Icons.schedule_outlined,
        label: 'Queued',
        value: '${a.queuedCount} song${a.queuedCount == 1 ? '' : 's'}',
      ));
    }
    if (a.waitingForWifi) {
      cards.add(const _ActivityCard(
        icon: Icons.wifi_off_outlined,
        label: 'Waiting',
        value: 'for Wi-Fi',
      ));
    } else if (a.failedCount > 0) {
      cards.add(_ActivityCard(
        icon: Icons.error_outline,
        label: 'Failed',
        value: '${a.failedCount} song${a.failedCount == 1 ? '' : 's'}',
        isError: true,
      ));
    }

    if (cards.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < cards.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: cards[i]),
          ],
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.icon,
    required this.label,
    required this.value,
    this.animateWaveform = false,
    this.isError = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool animateWaveform;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color accent = isError ? cs.error : heerrMagenta;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: accent),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (animateWaveform) ...<Widget>[
            const SizedBox(height: 6),
            WaveformStrip(height: 14, color: accent, animate: true, barWidth: 2, gap: 1.5),
          ],
        ],
      ),
    );
  }
}
