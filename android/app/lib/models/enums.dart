import 'package:json_annotation/json_annotation.dart';

/// Content type for search and download. Wire values match the backend's
/// `source_type` field (see `backend/app/schemas/search.py`).
enum ContentType {
  @JsonValue('song')
  song,
  @JsonValue('album')
  album,
  @JsonValue('playlist')
  playlist,
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
