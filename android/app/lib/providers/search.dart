import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api/client.dart';
import '../api/endpoints.dart';
import '../models/enums.dart';
import '../models/search_request.dart';
import '../models/search_response.dart';
import '../models/search_result_item.dart';

part 'search.g.dart';

const Duration _kDefaultSearchDebounce = Duration(milliseconds: 300);

/// Debounce applied to both the library and YouTube-Music search providers.
/// Exposed so tests can override it (typically to `Duration.zero`).
@Riverpod(keepAlive: true)
Duration searchDebounce(SearchDebounceRef ref) => _kDefaultSearchDebounce;

/// `POST /search` against the heerr backend (YouTube-Music search).
///
/// Family-keyed by the query string so the combined-search orchestrator can
/// pull the result for the current query directly. The standalone Search tab
/// no longer exists (subsumed by Library at I1/I2), so the old
/// `searchQueryProvider` + singleton `searchResultsProvider` are gone — query
/// is now an explicit parameter.
///
/// Empty / whitespace-only queries short-circuit to an empty `SearchResponse`
/// without hitting the network. Non-empty queries are debounced (default
/// 300ms via [searchDebounceProvider]) and any in-flight request is cancelled
/// when the family key changes via a `CancelToken` tied to `ref.onDispose`.
///
/// Content type is fixed to [ContentType.song] for now — the combined search
/// UI surfaces songs/albums/artists from the library half (via Subsonic
/// search3) and matches the YT half on songs. If we ever want to search YT
/// albums/playlists from the library tab, lift the type into the family key.
@riverpod
Future<SearchResponse> ytmSearch(YtmSearchRef ref, String query) async {
  if (query.trim().isEmpty) {
    return const SearchResponse(results: <SearchResultItem>[]);
  }

  final Duration debounce = ref.read(searchDebounceProvider);

  final CancelToken cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);

  await Future<void>.delayed(debounce);

  if (cancelToken.isCancelled) {
    throw const _DebounceCancelled();
  }

  final Dio dio = await ref.watch(dioClientProvider.future);
  final SearchRequest body = SearchRequest(
    query: query,
    type: ContentType.song,
  );
  return apiCall<SearchResponse>(
    () => dio.post<dynamic>(
      Endpoints.search,
      data: body.toJson(),
      cancelToken: cancelToken,
    ),
    (dynamic data) => SearchResponse.fromJson(data as Map<String, dynamic>),
  );
}

class _DebounceCancelled implements Exception {
  const _DebounceCancelled();
  @override
  String toString() => 'search debounce cancelled';
}
