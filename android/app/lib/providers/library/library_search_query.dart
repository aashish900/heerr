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

/// Whether the Library tab is currently showing its search overlay (V1).
/// `LibraryScreen` keeps this in sync with its local `_searching` state so
/// the shell's back-button handler (`_ShellScaffold`) can tell "Library is
/// searching" apart from "Library browse" — both live in the same go_router
/// route, so both their `PopScope`s fire on a system back. When searching,
/// the shell defers to `LibraryScreen`'s own back handler (clear + exit
/// search) instead of routing to Home.
@Riverpod(keepAlive: true)
class LibrarySearchActive extends _$LibrarySearchActive {
  @override
  bool build() => false;

  void set(bool active) {
    state = active;
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
