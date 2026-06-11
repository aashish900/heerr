import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../models/job_view.dart';
import '../providers/job_status.dart';
import '../widgets/error_snackbar.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_pill.dart';

/// One job's live view. Polls `GET /status/{jobId}` until the job reaches
/// a terminal state (`done` / `failed`), per `jobStatusProvider`.
class JobDetailScreen extends ConsumerWidget {
  const JobDetailScreen({required this.jobId, super.key});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<JobView> jobAsync =
        ref.watch(jobStatusProvider(jobId));
    ref.listen<AsyncValue<JobView>>(
      jobStatusProvider(jobId),
      (AsyncValue<JobView>? prev, AsyncValue<JobView> next) {
        reactToApiError<JobView>(context, prev, next);
      },
    );
    return Scaffold(
      appBar: AppBar(title: Text('Job ${_short(jobId)}')),
      body: jobAsync.when(
        loading: () => const _JobDetailSkeleton(),
        error: (Object e, _) =>
            Center(child: Text(e is ApiError ? e.message : 'Error: $e')),
        data: (JobView j) => _JobBody(job: j),
      ),
    );
  }
}

class _JobBody extends StatelessWidget {
  const _JobBody({required this.job});
  final JobView job;

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final String? name = job.displayName;
    final bool hasName = name != null && name.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Row(
          children: <Widget>[
            StatusPill(state: job.state),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                job.sourceType.name,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (hasName) ...<Widget>[
          Text(
            name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
        ],
        _Field(label: 'source url', value: job.sourceUrl, copyable: true),
        _Field(label: 'job id', value: job.jobId, copyable: true),
        _TimestampField(label: 'created', when: job.createdAt, now: now),
        if (job.startedAt != null)
          _TimestampField(label: 'started', when: job.startedAt!, now: now),
        if (job.finishedAt != null)
          _TimestampField(label: 'finished', when: job.finishedAt!, now: now),
        if (job.outputPath != null)
          _Field(label: 'output path', value: job.outputPath!, copyable: true),
        if (job.error != null) _ErrorField(message: job.error!),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  final String label;
  final String value;
  final bool copyable;

  Future<void> _copy(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: kSnackBarDuration,
        content: Text('Copied $label'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle? caption = Theme.of(context).textTheme.labelSmall;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label.toUpperCase(), style: caption),
          const SizedBox(height: 2),
          if (copyable)
            InkWell(
              onTap: () => _copy(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Icon(Icons.copy, size: 16),
                  ],
                ),
              ),
            )
          else
            Text(value),
        ],
      ),
    );
  }
}

class _TimestampField extends StatelessWidget {
  const _TimestampField({
    required this.label,
    required this.when,
    required this.now,
  });

  final String label;
  final DateTime when;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final TextStyle? caption = Theme.of(context).textTheme.labelSmall;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label.toUpperCase(), style: caption),
          const SizedBox(height: 2),
          Text(_relative(when, now)),
          Text(
            when.toIso8601String(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ErrorField extends StatelessWidget {
  const _ErrorField({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline, color: cs.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: TextStyle(color: cs.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

class _JobDetailSkeleton extends StatelessWidget {
  const _JobDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const <Widget>[
        Row(
          children: <Widget>[
            SkeletonBox(width: 80, height: 24, borderRadius: 12),
            SizedBox(width: 12),
            SkeletonBox(width: 60, height: 14),
          ],
        ),
        SizedBox(height: 24),
        SkeletonBox(width: 60, height: 10),
        SizedBox(height: 6),
        SkeletonBox(width: 240, height: 14),
        SizedBox(height: 20),
        SkeletonBox(width: 60, height: 10),
        SizedBox(height: 6),
        SkeletonBox(width: 200, height: 14),
        SizedBox(height: 20),
        SkeletonBox(width: 60, height: 10),
        SizedBox(height: 6),
        SkeletonBox(width: 160, height: 14),
      ],
    );
  }
}

String _short(String id) => id.length <= 8 ? id : id.substring(0, 8);

String _relative(DateTime when, DateTime now) {
  final Duration d = now.difference(when).abs();
  if (d.inSeconds < 60) return '${d.inSeconds}s ago';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}
