import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'download_response.freezed.dart';
part 'download_response.g.dart';

/// POST /api/v1/download response body.
/// Backend contract: `backend/app/schemas/download.py::DownloadResponse`.
/// `state` is the job state immediately after dispatch — typically
/// `queued` for new jobs, or `done`/`running` when `deduped == true`.
@freezed
class DownloadResponse with _$DownloadResponse {
  const factory DownloadResponse({
    required String jobId,
    required JobState state,
    required bool deduped,
  }) = _DownloadResponse;

  factory DownloadResponse.fromJson(Map<String, dynamic> json) =>
      _$DownloadResponseFromJson(json);
}
