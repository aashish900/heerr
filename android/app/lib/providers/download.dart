import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api/client.dart';
import '../api/endpoints.dart';
import '../models/download_request.dart';
import '../models/download_response.dart';

part 'download.g.dart';

/// Tracks which `spotify_uri`s have an in-flight `POST /download`. The state
/// is the **set of in-flight URIs**; UI watches its own URI's membership
/// (via `.select`) to render a spinner while the request is mid-flight.
///
/// `dispatch` is the imperative entry point — call it from a tap handler,
/// await the [DownloadResponse], and use `deduped` to choose snackbar copy.
/// The in-flight URI is removed in a `finally`, so a thrown [ApiError] still
/// leaves the tile responsive.
///
/// `keepAlive: true` so the in-flight set survives screen rebuilds (typing
/// in the query box rebuilds the result list — we don't want a tile-spinner
/// to flicker off when the list refreshes underneath it).
@Riverpod(keepAlive: true)
class DownloadDispatcher extends _$DownloadDispatcher {
  @override
  Set<String> build() => const <String>{};

  Future<DownloadResponse> dispatch(
    String spotifyUri, {
    String? displayName,
  }) async {
    state = <String>{...state, spotifyUri};
    try {
      final Dio dio = await ref.read(dioClientProvider.future);
      final DownloadRequest body = DownloadRequest(
        spotifyUri: spotifyUri,
        displayName: displayName,
      );
      return await apiCall<DownloadResponse>(
        () => dio.post<dynamic>(Endpoints.download, data: body.toJson()),
        (dynamic data) =>
            DownloadResponse.fromJson(data as Map<String, dynamic>),
      );
    } finally {
      state = <String>{...state}..remove(spotifyUri);
    }
  }
}
