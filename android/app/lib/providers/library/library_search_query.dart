import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'library_search_query.g.dart';

/// Current text of the Library tab's search field. `keepAlive: true` so the
/// last query survives tab switches (Library → Queue → Library), mirroring
/// the old standalone-Search-tab UX that this query state replaces.
///
/// The combined-search orchestrator [combinedSearchProvider] watches this
/// value and family-keys both [librarySearchProvider] and [ytmSearchProvider]
/// off it.
@Riverpod(keepAlive: true)
class LibrarySearchQuery extends _$LibrarySearchQuery {
  @override
  String build() => '';

  void set(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}
