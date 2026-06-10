import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'job_view.freezed.dart';
part 'job_view.g.dart';

/// One job as returned by /status/{id} and inside /queue.
/// Backend contract: `backend/app/schemas/job.py::JobView`.
/// `progress` is reserved by the backend (always `null` in v1).
@freezed
class JobView with _$JobView {
  const factory JobView({
    required String jobId,
    required String spotifyUri,
    required SpotifyType spotifyType,
    required JobState state,
    String? displayName,
    int? progress,
    String? error,
    String? outputPath,
    required DateTime createdAt,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) = _JobView;

  factory JobView.fromJson(Map<String, dynamic> json) =>
      _$JobViewFromJson(json);
}
