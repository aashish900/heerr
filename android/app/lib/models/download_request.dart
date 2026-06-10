import 'package:freezed_annotation/freezed_annotation.dart';

part 'download_request.freezed.dart';
part 'download_request.g.dart';

/// POST /api/v1/download request body.
/// Backend contract: `backend/app/schemas/download.py::DownloadRequest`.
@freezed
class DownloadRequest with _$DownloadRequest {
  const factory DownloadRequest({
    required String sourceUrl,
    required String sourceType,
    String? displayName,
  }) = _DownloadRequest;

  factory DownloadRequest.fromJson(Map<String, dynamic> json) =>
      _$DownloadRequestFromJson(json);
}
