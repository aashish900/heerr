import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../api/subsonic_client.dart';
import '../../api/subsonic_endpoints.dart';
import '../../models/subsonic/search_result3.dart';
import '../search.dart' show searchDebounceProvider;

part 'library_search.g.dart';

/// Wraps `GET /rest/search3.view?query=<q>`. Debounced via the existing
/// `searchDebounceProvider` (300ms by default) so rapid typing doesn't
/// hammer Navidrome.
///
/// Empty / whitespace-only queries short-circuit to an empty result without
/// firing a request. Mid-flight requests are cancelled when the query
/// changes via a `CancelToken` tied to `ref.onDispose`, mirroring the
/// existing YouTube-Music `searchResultsProvider`.
@riverpod
Future<SearchResult3> librarySearch(
  LibrarySearchRef ref,
  String query,
) async {
  if (query.trim().isEmpty) {
    return const SearchResult3();
  }

  final Duration debounce = ref.read(searchDebounceProvider);

  final CancelToken cancelToken = CancelToken();
  ref.onDispose(cancelToken.cancel);

  await Future<void>.delayed(debounce);

  if (cancelToken.isCancelled) {
    throw const _DebounceCancelled();
  }

  final Dio dio = await ref.watch(subsonicDioClientProvider.future);
  return subsonicCall<SearchResult3>(
    () => dio.get<dynamic>(
      SubsonicEndpoints.search3,
      queryParameters: <String, dynamic>{'query': query},
      cancelToken: cancelToken,
    ),
    (Map<String, dynamic> env) {
      final dynamic payload = env['searchResult3'];
      if (payload is! Map<String, dynamic>) {
        return const SearchResult3();
      }
      return SearchResult3.fromJson(payload);
    },
  );
}

class _DebounceCancelled implements Exception {
  const _DebounceCancelled();
  @override
  String toString() => 'library search debounce cancelled';
}
