// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_edit.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$libraryEditHash() => r'3ed72535fa754aaddf1008233735b881225f8343';

/// Y1 (#44): server-side song metadata editing. Same shape as [LibraryDelete]:
/// [editSong] drives the backend multipart `PATCH /library/song` through
/// [BackendService] and invalidates the read surfaces that could still show
/// stale tags. When a cover was uploaded it also evicts the L5 cover-cache
/// file for the song's `coverArt` id and clears the in-memory image cache —
/// Navidrome keeps the same cover id across a tag rescan, so without eviction
/// the widget would re-serve the old art from disk forever.
///
/// Navidrome only re-reads the file on its next scan (~1 min), so an
/// invalidated provider may transiently re-serve the old metadata — callers
/// word their success snackbar accordingly.
///
/// `keepAlive: true` because this notifier holds no mutable state and is
/// referenced from short-lived UI surfaces (the edit screen).
///
/// Copied from [LibraryEdit].
@ProviderFor(LibraryEdit)
final libraryEditProvider = NotifierProvider<LibraryEdit, void>.internal(
  LibraryEdit.new,
  name: r'libraryEditProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$libraryEditHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$LibraryEdit = Notifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
