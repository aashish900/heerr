import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/search_response.dart';
import '../models/search_result_item.dart';
import '../services/backend_service.dart';

part 'search.g.dart';

const Duration _kDefaultSearchDebounce = Duration(milliseconds: 300);

/// Debounce applied to both the library and online search providers.
/// Exposed so tests can override it (typically to `Duration.zero`).
@Riverpod(keepAlive: true)
Duration searchDebounce(SearchDebounceRef ref) => _kDefaultSearchDebounce;

/// `POST /search` against the heerr backend (online search), via
/// [BackendService].
///
/// Family-keyed by the query string so the combined-search orchestrator can
/// pull the result for the current query directly.
///
/// Empty / whitespace-only queries short-circuit to an empty `SearchResponse`
/// without hitting the network. Non-empty queries are debounced (default
/// 300ms via [searchDebounceProvider]) and any in-flight request is cancelled
/// when the family key changes via a `CancelToken` tied to `ref.onDispose`.
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

  final BackendService backend =
      await ref.watch(backendServiceProvider.future);
  return backend.ytmSearch(query, cancelToken: cancelToken);
}

class _DebounceCancelled implements Exception {
  const _DebounceCancelled();
  @override
  String toString() => 'search debounce cancelled';
}
