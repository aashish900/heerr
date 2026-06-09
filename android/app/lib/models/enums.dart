import 'package:json_annotation/json_annotation.dart';

/// Spotify entity kind. Wire values are the lowercase strings the backend
/// uses (see `backend/app/schemas/search.py` and `backend/app/schemas/job.py`).
enum SpotifyType {
  @JsonValue('track')
  track,
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
