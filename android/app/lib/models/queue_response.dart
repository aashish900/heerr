import 'package:freezed_annotation/freezed_annotation.dart';

import 'job_view.dart';

part 'queue_response.freezed.dart';
part 'queue_response.g.dart';

/// GET /api/v1/queue response body.
/// Backend contract: `backend/app/schemas/job.py::QueueResponse`.
@freezed
class QueueResponse with _$QueueResponse {
  const factory QueueResponse({
    required List<JobView> active,
    required List<JobView> recent,
  }) = _QueueResponse;

  factory QueueResponse.fromJson(Map<String, dynamic> json) =>
      _$QueueResponseFromJson(json);
}
