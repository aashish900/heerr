import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/jam_remote.dart';
import '../router.dart';
import '../theme.dart';

/// JM8: strip above the mini-player while this phone controls a jam host, so
/// it is obvious that Play / Add to queue go to the other phone. Tap opens
/// the jam screen; Leave returns control to this phone.
class JamRemoteBanner extends ConsumerWidget {
  const JamRemoteBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final JamRemoteStatus? jam = ref.watch(jamRemoteProvider);
    if (jam == null) return const SizedBox.shrink();
    return Material(
      color: heerrMagenta,
      child: InkWell(
        onTap: () => context.push(Routes.jam),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
          child: Row(
            children: <Widget>[
              const Icon(Icons.settings_remote, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Controlling ${jam.hostUsername}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => ref.read(jamRemoteProvider.notifier).leave(),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Leave'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
