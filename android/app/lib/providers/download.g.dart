// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$downloadDispatcherHash() =>
    r'bf59ef5efdeaecd4b3555b62d685766b966d8e48';

/// Tracks which `source_url`s have an in-flight `POST /download`. The state
/// is the **set of in-flight URLs**; UI watches its own URL's membership
/// (via `.select`) to render a spinner while the request is mid-flight.
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
