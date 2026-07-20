import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_error.dart';
import '../models/enums.dart';
import '../models/job_view.dart';
import '../services/backend_service.dart';
import '../models/queue_response.dart';
import '../player/playback_actions.dart';
import '../providers/queue.dart';
import '../router.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_snackbar.dart';
import '../widgets/gradient_tab_indicator.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_pill.dart';

/// Polled queue view. Two sections (Active / Recent), each a list of
/// `JobView` tiles with a colour-coded `StatusPill`. A Music/Podcasts
/// content switch (#53) filters both sections by `job.sourceType` — same
/// pattern as Home/Library's content switches.
///
/// Lifecycle binding: `WidgetsBindingObserver` forwards background/foreground
/// transitions to the provider's `pause()` / `resume()` per PLAN.md §8.
class QueueScreen extends ConsumerStatefulWidget {
  const QueueScreen({super.key});

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final TabController _contentController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Both tabs read the same already-fetched `queueProvider` snapshot (just
    // filtered client-side by sourceType), so — unlike Home/Library's
    // content switches — there's no extra network call to avoid by delaying
    // the Podcasts tab's build. A manual TabController is still used so the
    // switch stays visually consistent with Home's/Library's.
    _contentController = TabController(length: 2, vsync: this);
    _contentController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _contentController.dispose();
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
    final bool podcasts = _contentController.index == 1;
    return Scaffold(
      appBar: AppBar(title: const Text('Queue')),
      body: Column(
        children: <Widget>[
          _QueueContentSwitch(controller: _contentController),
          Expanded(
            child: queueAsync.when(
              loading: () => const SkeletonList(count: 4),
              error: (Object e, _) =>
                  Center(child: Text(e is ApiError ? e.message : 'Error: $e')),
              data: (QueueResponse r) {
                bool matches(JobView j) =>
                    (j.sourceType == ContentType.episode) == podcasts;
                final List<JobView> active = r.active.where(matches).toList();
                final List<JobView> recent = r.recent.where(matches).toList();

                if (active.isEmpty && recent.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => ref.read(queueProvider.notifier).resume(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: <Widget>[
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.5,
                          child: Center(
                            child: EmptyState(
                              icon: podcasts
                                  ? Icons.podcasts
                                  : Icons.queue_music,
                              title: 'No jobs yet',
                              subtitle: podcasts
                                  ? 'Download a podcast episode to see it here'
                                  : 'Search and tap a track to queue a download',
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(queueProvider.notifier).resume(),
                  child: ListView(
                    children: <Widget>[
                      if (active.isNotEmpty) ...<Widget>[
                        const _SectionHeader(label: 'Active'),
                        for (final JobView j in active) _JobTile(job: j),
                      ],
                      if (recent.isNotEmpty) ...<Widget>[
                        const _SectionHeader(label: 'Recent'),
                        for (final JobView j in recent) _JobTile(job: j),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Music / Podcasts top-level switch — same visual pattern as Home's
/// `_HomeContentSwitch` / Library's `_LibraryContentSwitch`
/// (`GradientTabIndicator` + `heerrMagenta`).
class _QueueContentSwitch extends StatelessWidget {
  const _QueueContentSwitch({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return TabBar(
      controller: controller,
      indicator: const GradientTabIndicator(),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelColor: heerrMagenta,
      unselectedLabelColor: cs.onSurfaceVariant,
      tabs: const <Tab>[
        Tab(height: 46, child: Text('Music')),
        Tab(height: 46, child: Text('Podcasts')),
      ],
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

class _JobTile extends ConsumerWidget {
  const _JobTile({required this.job});
  final JobView job;

  bool get _isActive =>
      job.state == JobState.queued || job.state == JobState.running;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? name = job.displayName;
    final bool hasName = name != null && name.isNotEmpty;
    return ListTile(
      tileColor: _isActive ? heerrMagenta.withValues(alpha: 0.12) : null,
      title: Text(
        hasName ? name : job.sourceUrl,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: hasName
            ? const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)
            : const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
      subtitle: Text(
        'job ${_shortId(job.jobId)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (job.state == JobState.done)
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: 'Play',
              onPressed: () => playJobDoneFromSubsonic(ref, context, job),
            ),
          if (job.state == JobState.failed)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Retry',
              onPressed: () => _retry(context, ref),
            ),
          StatusPill(state: job.state),
        ],
      ),
      onTap: () => context.push(Routes.job(job.jobId)),
    );
  }

  /// Retries a failed job. Episode jobs (`sourceType == episode`) can't be
  /// retried via the song-download endpoint — their `sourceUrl` is a
  /// podcast enclosure URL, not a YouTube/YouTube Music URL, so
  /// `POST /download` rejects it with a 422. Episode jobs instead
  /// re-dispatch via `POST /podcasts/episodes/{episodeId}/download`, the
  /// same idempotent-create path the original Download button uses.
  Future<void> _retry(BuildContext context, WidgetRef ref) async {
    try {
      final BackendService svc = await ref.read(backendServiceProvider.future);
      if (job.sourceType == ContentType.episode) {
        final String? episodeId = job.episodeId;
        if (episodeId == null) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            duration: kSnackBarDuration,
            content: Text("Can't retry: missing episode id"),
          ));
          return;
        }
        await svc.downloadPodcastEpisode(episodeId);
      } else {
        await svc.download(
          sourceUrl: job.sourceUrl,
          sourceType: job.sourceType.name,
          displayName: job.displayName,
        );
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          duration: kSnackBarDuration,
          content: Text('Queued'),
        ));
    } on ApiError catch (e) {
      if (!context.mounted) return;
      showApiError(context, e);
    }
  }

  String _shortId(String id) {
    return id.length <= 8 ? id : id.substring(0, 8);
  }
}
