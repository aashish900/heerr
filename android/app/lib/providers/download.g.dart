// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$downloadDispatcherHash() =>
    r'a0e1ad071acac6f9b884baa70b273fcce13cd250';

/// Tracks which `spotify_uri`s have an in-flight `POST /download`. The state
/// is the **set of in-flight URIs**; UI watches its own URI's membership
/// (via `.select`) to render a spinner while the request is mid-flight.
///
/// `dispatch` is the imperative entry point — call it from a tap handler,
/// await the [DownloadResponse], and use `deduped` to choose snackbar copy.
/// The in-flight URI is removed in a `finally`, so a thrown [ApiError] still
/// leaves the tile responsive.
///
/// `keepAlive: true` so the in-flight set survives screen rebuilds (typing
/// in the query box rebuilds the result list — we don't want a tile-spinner
/// to flicker off when the list refreshes underneath it).
///
/// Copied from [DownloadDispatcher].
@ProviderFor(DownloadDispatcher)
final downloadDispatcherProvider =
    NotifierProvider<DownloadDispatcher, Set<String>>.internal(
      DownloadDispatcher.new,
      name: r'downloadDispatcherProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$downloadDispatcherHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$DownloadDispatcher = Notifier<Set<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
