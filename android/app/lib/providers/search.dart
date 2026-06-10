import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api/client.dart';
import '../api/endpoints.dart';
import '../models/enums.dart';
import '../models/search_request.dart';
import '../models/search_response.dart';
import '../models/search_result_item.dart';

part 'search.g.dart';

/// Current search bar state.
typedef SearchQueryState = ({String query, ContentType type});

const Duration _kDefaultSearchDebounce = Duration(milliseconds: 300);

@Riverpod(keepAlive: true)
Duration searchDebounce(SearchDebounceRef ref) => _kDefaultSearchDebounce;

/// Search bar state. `keepAlive: true` because the user's last query should
/// survive tab switches (Search → Queue → Search).
@Riverpod(keepAlive: true)
class SearchQuery extends _$SearchQuery {
  @override
  SearchQueryState build() => (query: '', type: ContentType.song);

  void setQuery(String query) {
    state = (query: query, type: state.type);
  }

  void setType(ContentType type) {
    state = (query: state.query, type: type);
  }
}

/// `POST /search` results for the current query. Empty query short-circuits
/// to an empty `SearchResponse` without hitting the network. Non-empty
/// queries are debounced (default 300ms) and any in-flight request is
/// cancelled when the query changes — via a `CancelToken` tied to
/// `ref.onDispose`.
@riverpod
Future<SearchResponse> searchResults(SearchResultsRef ref) async {
  final SearchQueryState query = ref.watch(searchQueryProvider);
  final Duration debounce = ref.read(searchDebounceProvider);

  if (query.query.trim().isEmpty) {
    return const SearchResponse(results: <SearchResultItem>[]);
  }

  final CancelToken cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);

  await Future<void>.delayed(debounce);

  if (cancelToken.isCancelled) {
    throw const _DebounceCancelled();
  }

  final Dio dio = await ref.watch(dioClientProvider.future);
  final SearchRequest body = SearchRequest(
    query: query.query,
    type: query.type,
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
