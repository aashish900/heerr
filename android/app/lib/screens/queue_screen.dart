import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_error.dart';
import '../models/job_view.dart';
import '../models/queue_response.dart';
import '../providers/queue.dart';
import '../router.dart';
import '../widgets/error_snackbar.dart';
import '../widgets/status_pill.dart';

/// Polled queue view. Two sections (Active / Recent), each a list of
/// `JobView` tiles with a colour-coded `StatusPill`.
///
/// Lifecycle binding: `WidgetsBindingObserver` forwards background/foreground
/// transitions to the provider's `pause()` / `resume()` per PLAN.md §8.
class QueueScreen extends ConsumerStatefulWidget {
  const QueueScreen({super.key});

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        ref.read(queueProvider.notifier).pause();
      case AppLifecycleState.resumed:
        // Fire-and-forget; the provider updates state on completion.
        unawaited(ref.read(queueProvider.notifier).resume());
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<QueueResponse> queueAsync = ref.watch(queueProvider);
    ref.listen<AsyncValue<QueueResponse>>(
      queueProvider,
      (AsyncValue<QueueResponse>? prev, AsyncValue<QueueResponse> next) {
        reactToApiError<QueueResponse>(context, prev, next);
      },
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Queue')),
      body: queueAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) =>
            Center(child: Text(e is ApiError ? e.message : 'Error: $e')),
        data: (QueueResponse r) {
          if (r.active.isEmpty && r.recent.isEmpty) {
            return const Center(child: Text('No jobs yet'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(queueProvider.notifier).resume(),
            child: ListView(
              children: <Widget>[
                if (r.active.isNotEmpty) ...<Widget>[
                  const _SectionHeader(label: 'Active'),
                  for (final JobView j in r.active) _JobTile(job: j),
                ],
                if (r.recent.isNotEmpty) ...<Widget>[
                  const _SectionHeader(label: 'Recent'),
                  for (final JobView j in r.recent) _JobTile(job: j),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _JobTile extends StatelessWidget {
  const _JobTile({required this.job});
  final JobView job;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        job.spotifyUri,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
      subtitle: Text(
        'job ${_shortId(job.jobId)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: StatusPill(state: job.state),
      onTap: () => context.push(Routes.job(job.jobId)),
    );
  }

  String _shortId(String id) {
    return id.length <= 8 ? id : id.substring(0, 8);
  }
}
