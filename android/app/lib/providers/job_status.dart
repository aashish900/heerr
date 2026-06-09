import 'dart:async';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api/client.dart';
import '../api/endpoints.dart';
import '../models/enums.dart';
import '../models/job_view.dart';

part 'job_status.g.dart';

const Duration _kDefaultJobStatusPollInterval = Duration(seconds: 2);

/// Polling interval for `GET /status/{id}`. Default 2s per PLAN.md §8;
/// exposed as a provider so tests override to short durations.
@Riverpod(keepAlive: true)
Duration jobStatusPollInterval(JobStatusPollIntervalRef ref) =>
    _kDefaultJobStatusPollInterval;

/// Polls `GET /status/{jobId}` every 2s **while the job state is
/// non-terminal**, stops once `state ∈ {done, failed}`. Auto-disposes when
/// the last listener detaches (the screen) so navigating away cancels the
/// in-flight poll cycle.
///
/// Family argument is the `jobId` (UUID string). Two open job-detail
/// screens for different jobs would each get their own provider instance.
@riverpod
class JobStatus extends _$JobStatus {
  Timer? _timer;

  @override
  Future<JobView> build(String jobId) async {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    final JobView first = await _fetch(jobId);
    if (!first.state.isTerminal) {
      _scheduleNext(jobId);
    }
    return first;
  }

  void _scheduleNext(String jobId) {
    _timer?.cancel();
    final Duration interval = ref.read(jobStatusPollIntervalProvider);
    _timer = Timer(interval, () => _tick(jobId));
  }

  Future<void> _tick(String jobId) async {
    state = await AsyncValue.guard(() => _fetch(jobId));
    final JobView? current = state.valueOrNull;
    // Stop only on terminal state. Errors keep polling — transient failures
    // (network blip) shouldn't strand the screen.
    if (current == null || !current.state.isTerminal) {
      _scheduleNext(jobId);
    }
  }

  Future<JobView> _fetch(String jobId) async {
    final Dio dio = await ref.read(dioClientProvider.future);
    return apiCall<JobView>(
      () => dio.get<dynamic>(Endpoints.status(jobId)),
      (dynamic data) => JobView.fromJson(data as Map<String, dynamic>),
    );
  }
}
