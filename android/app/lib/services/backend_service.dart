import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api/client.dart';
import '../api/endpoints.dart';
import '../models/download_request.dart';
import '../models/download_response.dart';
import '../models/enums.dart';
import '../models/episode_download_response.dart';
import '../models/episode_list_response.dart';
import '../models/episode_progress.dart';
import '../models/job_view.dart';
import '../models/podcast_channel.dart';
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

  /// `POST /search` (online search). Content type fixed to song to
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

  /// `GET /health` → `{"status": "ok"}` when the backend is reachable.
  /// DL2 (Downloads "Sync Center" hero, D1): the only reachability probe the
  /// thin client performs — it never talks to Navidrome directly, so "online"
  /// here means "the backend pipeline that talks to Navidrome is alive", not
  /// a direct Navidrome ping.
  Future<bool> health() {
    return apiCall<bool>(
      () => _dio.get<dynamic>(Endpoints.health),
      (dynamic data) =>
          data is Map && data['status'] == 'ok',
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

  /// `DELETE /library/song` → remove a track file from the server's music
  /// library by its Navidrome-relative path (Subsonic `song.path`). The
  /// backend also clears its already-downloaded dedupe state for the file;
  /// Navidrome drops the track from the library on its next scan (~1 min).
  Future<void> deleteLibrarySong(String path) {
    return apiCall<void>(
      () => _dio.delete<dynamic>(
        Endpoints.libraryDeleteSong,
        data: <String, String>{'path': path},
      ),
      (dynamic data) {},
    );
  }

  /// `PATCH /library/song` (#44) → rewrite a track's tags and/or embedded
  /// cover art in place. Sent as multipart so tags + cover travel in one
  /// request; only the provided fields are included. The backend never
  /// renames the file, so `Song.path` stays stable; Navidrome re-reads the
  /// tags on its next scan (~1 min). [coverBytes] must be JPEG or PNG.
  Future<void> editLibrarySong({
    required String path,
    String? title,
    String? album,
    String? artist,
    Uint8List? coverBytes,
  }) {
    final FormData form = FormData.fromMap(<String, dynamic>{
      'path': path,
      'title': ?title,
      'album': ?album,
      'artist': ?artist,
      if (coverBytes != null)
        'cover': MultipartFile.fromBytes(
          coverBytes,
          filename: 'cover.jpg',
          contentType: DioMediaType('image', 'jpeg'),
        ),
    });
    return apiCall<void>(
      () => _dio.patch<dynamic>(Endpoints.libraryEditSong, data: form),
      (dynamic data) {},
    );
  }

  /// `GET /status/{jobId}` → one job's current view.
  Future<JobView> jobStatus(String jobId) {
    return apiCall<JobView>(
      () => _dio.get<dynamic>(Endpoints.status(jobId)),
      (dynamic data) => JobView.fromJson(data as Map<String, dynamic>),
    );
  }

  /// `POST /auth/logout` (Phase Z) → revokes the current bearer token
  /// server-side. Callers treat this as best-effort: the local sign-out
  /// (`ProfileRegistry.setActive(null)`) must proceed even when the
  /// backend is unreachable, so failures here are the caller's to swallow.
  Future<void> logout() {
    return apiCall<void>(
      () => _dio.post<dynamic>(Endpoints.authLogout),
      (dynamic data) {},
    );
  }

  /// `POST /podcasts/search` (Phase P, #53) → Podcast Index results. Not yet
  /// ingested, so each [PodcastChannel] has a null `id`.
  Future<List<PodcastChannel>> searchPodcasts(
    String query, {
    int limit = 20,
  }) {
    return apiCall<List<PodcastChannel>>(
      () => _dio.post<dynamic>(
        Endpoints.podcastSearch,
        data: <String, dynamic>{'query': query, 'limit': limit},
      ),
      (dynamic data) {
        final Map<String, dynamic> json = data as Map<String, dynamic>;
        final List<dynamic> results = json['results'] as List<dynamic>;
        return results
            .map((dynamic e) =>
                PodcastChannel.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
  }

  /// `POST /podcasts/subscribe` → ingests the feed (if new) and subscribes
  /// the calling user, returning the ingested channel (`id` set).
  Future<PodcastChannel> subscribePodcast(String feedUrl) {
    return apiCall<PodcastChannel>(
      () => _dio.post<dynamic>(
        Endpoints.podcastSubscribe,
        data: <String, dynamic>{'feed_url': feedUrl},
      ),
      (dynamic data) => PodcastChannel.fromJson(data as Map<String, dynamic>),
    );
  }

  /// `DELETE /podcasts/subscribe/{channelId}`.
  Future<void> unsubscribePodcast(String channelId) {
    return apiCall<void>(
      () => _dio.delete<dynamic>(Endpoints.podcastUnsubscribe(channelId)),
      (dynamic data) {},
    );
  }

  /// `GET /podcasts/subscriptions` → the calling user's subscribed channels.
  Future<List<PodcastChannel>> podcastSubscriptions() {
    return apiCall<List<PodcastChannel>>(
      () => _dio.get<dynamic>(Endpoints.podcastSubscriptions),
      (dynamic data) {
        final Map<String, dynamic> json = data as Map<String, dynamic>;
        final List<dynamic> channels = json['channels'] as List<dynamic>;
        return channels
            .map((dynamic e) =>
                PodcastChannel.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
  }

  /// `GET /podcasts/channels/{channelId}/episodes` → a page of episodes,
  /// newest-published first, with the calling user's progress joined in.
  Future<EpisodeListResponse> podcastEpisodes(
    String channelId, {
    int limit = 20,
    int offset = 0,
  }) {
    return apiCall<EpisodeListResponse>(
      () => _dio.get<dynamic>(
        Endpoints.podcastChannelEpisodes(channelId),
        queryParameters: <String, dynamic>{'limit': limit, 'offset': offset},
      ),
      (dynamic data) =>
          EpisodeListResponse.fromJson(data as Map<String, dynamic>),
    );
  }

  /// `POST /podcasts/channels/{channelId}/refresh` → re-pulls the RSS feed
  /// for new episodes.
  Future<PodcastChannel> refreshPodcastChannel(String channelId) {
    return apiCall<PodcastChannel>(
      () => _dio.post<dynamic>(Endpoints.podcastChannelRefresh(channelId)),
      (dynamic data) => PodcastChannel.fromJson(data as Map<String, dynamic>),
    );
  }

  /// `POST /podcasts/episodes/{episodeId}/download` → enqueues an episode
  /// download job (same `jobs` queue as song downloads, `source_type
  /// == 'episode'`; reflected in [getQueue]).
  Future<EpisodeDownloadResponse> downloadPodcastEpisode(String episodeId) {
    return apiCall<EpisodeDownloadResponse>(
      () => _dio.post<dynamic>(Endpoints.podcastEpisodeDownload(episodeId)),
      (dynamic data) =>
          EpisodeDownloadResponse.fromJson(data as Map<String, dynamic>),
    );
  }

  /// `PUT /podcasts/episodes/{episodeId}/progress` → upserts the calling
  /// user's resume position for the episode.
  Future<EpisodeProgress> updateEpisodeProgress(
    String episodeId, {
    required int positionS,
    required bool played,
  }) {
    return apiCall<EpisodeProgress>(
      () => _dio.put<dynamic>(
        Endpoints.podcastEpisodeProgress(episodeId),
        data: <String, dynamic>{'position_s': positionS, 'played': played},
      ),
      (dynamic data) => EpisodeProgress.fromJson(data as Map<String, dynamic>),
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
