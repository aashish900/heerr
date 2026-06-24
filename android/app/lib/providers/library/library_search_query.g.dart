// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_search_query.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$librarySearchQueryHash() =>
    r'ecd18e21e3c5a9d4a3bfd5f0e8085f89f59fb22f';

/// Current text of the Library tab's search field. `keepAlive: true` so the
/// last query survives tab switches (Library → Queue → Library), mirroring
/// the old standalone-Search-tab UX that this query state replaces.
///
/// The combined-search orchestrator [combinedSearchProvider] watches this
/// value and family-keys both [librarySearchProvider] and [ytmSearchProvider]
/// off it.
///
/// Copied from [LibrarySearchQuery].
@ProviderFor(LibrarySearchQuery)
final librarySearchQueryProvider =
    NotifierProvider<LibrarySearchQuery, String>.internal(
      LibrarySearchQuery.new,
      name: r'librarySearchQueryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$librarySearchQueryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$LibrarySearchQuery = Notifier<String>;
String _$librarySearchActiveHash() =>
    r'd83d68008ab3f6e82ffc8379108bac5c351a2494';

/// Whether the Library tab is currently showing its search overlay (V1).
/// `LibraryScreen` keeps this in sync with its local `_searching` state so
/// the shell's back-button handler (`_ShellScaffold`) can tell "Library is
/// searching" apart from "Library browse" — both live in the same go_router
/// route, so both their `PopScope`s fire on a system back. When searching,
/// the shell defers to `LibraryScreen`'s own back handler (clear + exit
/// search) instead of routing to Home.
///
/// Copied from [LibrarySearchActive].
@ProviderFor(LibrarySearchActive)
final librarySearchActiveProvider =
    NotifierProvider<LibrarySearchActive, bool>.internal(
      LibrarySearchActive.new,
      name: r'librarySearchActiveProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$librarySearchActiveHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$LibrarySearchActive = Notifier<bool>;
String _$librarySearchAutoFocusHash() =>
    r'c55b892985420976e3ad57c16227eaf7e110342a';

/// One-shot flag flipped by surfaces outside the Library tab (Home's
/// search shortcut) to request that Library auto-enter search mode on
/// next mount. The LibraryScreen reads it in `initState`, applies it,
/// then resets it so a later plain tap on the Library tab doesn't
/// reopen search.
///
/// Copied from [LibrarySearchAutoFocus].
@ProviderFor(LibrarySearchAutoFocus)
final librarySearchAutoFocusProvider =
    NotifierProvider<LibrarySearchAutoFocus, bool>.internal(
      LibrarySearchAutoFocus.new,
      name: r'librarySearchAutoFocusProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$librarySearchAutoFocusHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$LibrarySearchAutoFocus = Notifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
