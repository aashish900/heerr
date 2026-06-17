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

/// One-shot flag flipped by surfaces outside the Library tab (Home's
/// search shortcut) to request that Library auto-enter search mode on
/// next mount. The LibraryScreen reads it in `initState`, applies it,
/// then resets it so a later plain tap on the Library tab doesn't
/// reopen search.
@Riverpod(keepAlive: true)
class LibrarySearchAutoFocus extends _$LibrarySearchAutoFocus {
  @override
  bool build() => false;

  void request() {
    state = true;
  }

  void consume() {
    state = false;
  }
}
