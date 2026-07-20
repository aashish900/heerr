import 'package:json_annotation/json_annotation.dart';

/// Content type for search and download. Wire values match the backend's
/// `source_type` field (see `backend/app/schemas/search.py`,
/// `backend/app/schemas/job.py::JobView.source_type`).
///
/// `episode` (Phase P, #53) covers podcast episode download jobs — `jobs`
/// reuses the same `source_type` column for both, so `JobView.fromJson`
/// (used by `GET /queue` and `GET /status/{id}`) would throw on any episode
/// job if this value were missing, same as the backend-side Literal that
/// had to be widened at P5.
enum ContentType {
  @JsonValue('song')
  song,
  @JsonValue('album')
  album,
  @JsonValue('playlist')
  playlist,
  @JsonValue('episode')
  episode,
}

/// Job lifecycle state. Mirrors the backend's CHECK constraint on
/// `jobs.state` (see migration 0001).
enum JobState {
  @JsonValue('queued')
  queued,
  @JsonValue('running')
  running,
  @JsonValue('done')
  done,
  @JsonValue('failed')
  failed,
}

extension JobStateX on JobState {
  bool get isTerminal => this == JobState.done || this == JobState.failed;
}
