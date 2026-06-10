import 'package:freezed_annotation/freezed_annotation.dart';

part 'download_request.freezed.dart';
part 'download_request.g.dart';

/// POST /api/v1/download request body.
/// Backend contract: `backend/app/schemas/download.py::DownloadRequest`.
/// The backend infers the spotify entity type from the URI prefix
/// (`spotify:track:…` / `spotify:album:…` / `spotify:playlist:…`).
@freezed
class DownloadRequest with _$DownloadRequest {
  const factory DownloadRequest({
    required String spotifyUri,
    String? displayName,
  }) = _DownloadRequest;

  factory DownloadRequest.fromJson(Map<String, dynamic> json) =>
      _$DownloadRequestFromJson(json);
}
