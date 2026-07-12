import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../offline/offline_sync.dart';
import '../../router.dart';
import '../../theme.dart';
import '../../widgets/error_snackbar.dart';

/// Downloads "Sync Center" quick actions (DL3, DOWNLOADSSCREEN.md §"Quick
/// Actions"): Sync Now (manual `OfflineSync.syncNow()`, same result copy as
/// the Settings > Offline "Sync now" button) and Manage Storage (routes to
/// Settings, where the offline/storage controls already live).
class QuickActionCards extends StatelessWidget {
  const QuickActionCards({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: <Widget>[
          Expanded(child: _SyncNowCard()),
          SizedBox(width: 12),
          Expanded(child: _ManageStorageCard()),
        ],
      ),
    );
  }
}

class _QuickActionShell extends StatelessWidget {
  const _QuickActionShell({
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: <Widget>[
              busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(icon, color: heerrMagenta),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncNowCard extends ConsumerStatefulWidget {
  const _SyncNowCard();

  @override
  ConsumerState<_SyncNowCard> createState() => _SyncNowCardState();
}

class _SyncNowCardState extends ConsumerState<_SyncNowCard> {
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
    return _QuickActionShell(
      icon: Icons.sync,
      label: 'Sync Now',
      busy: _busy,
      onTap: _busy ? null : _runSync,
    );
  }
}

class _ManageStorageCard extends StatelessWidget {
  const _ManageStorageCard();

  @override
  Widget build(BuildContext context) {
    return _QuickActionShell(
      icon: Icons.storage_outlined,
      label: 'Manage Storage',
      onTap: () => context.push(Routes.settings),
    );
  }
}
