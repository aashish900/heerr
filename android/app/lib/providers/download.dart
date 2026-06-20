import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/download_response.dart';
import '../services/backend_service.dart';

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
      final BackendService backend =
          await ref.read(backendServiceProvider.future);
      return await backend.download(
        sourceUrl: sourceUrl,
        sourceType: sourceType,
        displayName: displayName,
      );
    } finally {
      state = <String>{...state}..remove(sourceUrl);
    }
  }
}
