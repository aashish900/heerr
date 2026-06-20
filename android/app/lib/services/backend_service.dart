import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api/client.dart';
import '../api/endpoints.dart';
import '../models/download_request.dart';
import '../models/download_response.dart';
import '../models/enums.dart';
import '../models/job_view.dart';
import '../models/queue_response.dart';
import '../models/recommend_health.dart';
import '../models/recommended_track.dart';
import '../models/search_request.dart';
import '../models/search_response.dart';
import '../models/seed_track.dart';

part 'backend_service.g.dart';

/// A10: transport+JSON seam for the heerr FastAPI backend (everything that
/// goes through the bearer-auth [dioClientProvider]). Holds only the [Dio] it
/// was handed; each method issues one request through [apiCall] (auth +
/// [ApiError] mapping centralised) and returns a typed model. No `Ref`, so it
/// unit-tests against a scripted dio adapter without a container.
class BackendService {
  const BackendService(this._dio);

  final Dio _dio;

  /// `POST /search` (YouTube-Music search). Content type fixed to song to
  /// match the combined-search UI. [cancelToken] aborts a superseded request.
  Future<SearchResponse> ytmSearch(String query, {CancelToken? cancelToken}) {
    final SearchRequest body =
        SearchRequest(query: query, type: ContentType.song);
    return apiCall<SearchResponse>(
      () => _dio.post<dynamic>(
        Endpoints.search,
        data: body.toJson(),
        cancelToken: cancelToken,
      ),
      (dynamic data) => SearchResponse.fromJson(data as Map<String, dynamic>),
    );
  }

  /// `POST /recommend` with `{seeds, limit}` → the parsed result list.
  Future<List<RecommendedTrack>> recommend({
    required List<SeedTrack> seeds,
    required int limit,
  }) {
    final Map<String, dynamic> body = <String, dynamic>{
      'seeds': seeds.map((SeedTrack s) => s.toJson()).toList(),
      'limit': limit,
    };
    return apiCall<List<RecommendedTrack>>(
      () => _dio.post<dynamic>(Endpoints.recommend, data: body),
      (dynamic data) {
        final Map<String, dynamic> json = data as Map<String, dynamic>;
        final dynamic results = json['results'];
        if (results is! List) return <RecommendedTrack>[];
        return results
            .map((dynamic e) =>
                RecommendedTrack.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
  }

  /// `GET /recommend/health` → the configured engine's health.
  Future<RecommendHealth> recommendHealth() {
    return apiCall<RecommendHealth>(
      () => _dio.get<dynamic>(Endpoints.recommendHealth),
      (dynamic data) => RecommendHealth.fromJson(data as Map<String, dynamic>),
    );
  }

  /// `GET /queue` → the current download queue snapshot.
  Future<QueueResponse> getQueue() {
    return apiCall<QueueResponse>(
      () => _dio.get<dynamic>(Endpoints.queue),
      (dynamic data) => QueueResponse.fromJson(data as Map<String, dynamic>),
    );
  }

  /// `POST /download` → enqueue a download job.
  Future<DownloadResponse> download({
    required String sourceUrl,
    required String sourceType,
    String? displayName,
  }) {
    final DownloadRequest body = DownloadRequest(
      sourceUrl: sourceUrl,
      sourceType: sourceType,
      displayName: displayName,
    );
    return apiCall<DownloadResponse>(
      () => _dio.post<dynamic>(Endpoints.download, data: body.toJson()),
      (dynamic data) =>
          DownloadResponse.fromJson(data as Map<String, dynamic>),
    );
  }

  /// `GET /status/{jobId}` → one job's current view.
  Future<JobView> jobStatus(String jobId) {
    return apiCall<JobView>(
      () => _dio.get<dynamic>(Endpoints.status(jobId)),
      (dynamic data) => JobView.fromJson(data as Map<String, dynamic>),
    );
  }
}

/// Async provider so the service is built once the bearer-auth [Dio] is ready.
/// Tests that override `dioClientProvider` flow through unchanged.
@riverpod
Future<BackendService> backendService(BackendServiceRef ref) async {
  final Dio dio = await ref.watch(dioClientProvider.future);
  return BackendService(dio);
}
