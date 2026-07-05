// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_delete.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$libraryDeleteHash() => r'5860b6241b33b98b5d5be0c228555455e66e3b73';

/// W1 (#41): server-side song deletion. Stateless notifier (same shape as
/// `PlaylistMutations`): [deleteFromServer] drives the backend
/// `DELETE /library/song` through [BackendService] and invalidates the read
/// surfaces that could still list the track.
///
/// Navidrome only drops the track on its next scan (~1 min), so an
/// invalidated provider may transiently re-serve the song from Navidrome —
/// callers word their success snackbar accordingly.
///
/// `keepAlive: true` because this notifier holds no mutable state and is
/// referenced from short-lived UI surfaces (sheets, dialogs).
///
/// Copied from [LibraryDelete].
@ProviderFor(LibraryDelete)
final libraryDeleteProvider = NotifierProvider<LibraryDelete, void>.internal(
  LibraryDelete.new,
  name: r'libraryDeleteProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$libraryDeleteHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$LibraryDelete = Notifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
