import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api/client.dart';
import '../api/endpoints.dart';
import '../models/download_request.dart';
import '../models/download_response.dart';

part 'download.g.dart';

/// Tracks which `source_url`s have an in-flight `POST /download`. The state
/// is the **set of in-flight URLs**; UI watches its own URL's membership
/// (via `.select`) to render a spinner while the request is mid-flight.
@Riverpod(keepAlive: true)
class DownloadDispatcher extends _$DownloadDispatcher {
  @override
  Set<String> build() => const <String>{};

  Future<DownloadResponse> dispatch(
    String sourceUrl, {
    required String sourceType,
    String? displayName,
  }) async {
    state = <String>{...state, sourceUrl};
    try {
      final Dio dio = await ref.read(dioClientProvider.future);
      final DownloadRequest body = DownloadRequest(
        sourceUrl: sourceUrl,
        sourceType: sourceType,
        displayName: displayName,
      );
      return await apiCall<DownloadResponse>(
        () => dio.post<dynamic>(Endpoints.download, data: body.toJson()),
        (dynamic data) =>
            DownloadResponse.fromJson(data as Map<String, dynamic>),
      );
    } finally {
      state = <String>{...state}..remove(sourceUrl);
    }
  }
}
