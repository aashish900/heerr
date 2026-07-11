import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/subsonic/song.dart';
import '../../offline/offline_paths.dart';
import '../../services/backend_service.dart';
import '../downloaded_songs.dart';
import '../home/home_providers.dart';
import '../server_creds.dart';
import 'starred_songs.dart';
import 'library_album.dart';
import 'library_albums.dart';
import 'library_artists.dart';
import 'library_search.dart';

part 'library_edit.g.dart';

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
@Riverpod(keepAlive: true)
class LibraryEdit extends _$LibraryEdit {
  @override
  void build() {}

  /// Edit [song]'s tags and/or embedded cover. At least one of [title],
  /// [album], [artist], [coverBytes] must be non-null. Throws [StateError]
  /// when the song carries no Subsonic `path` or nothing was supplied (both
  /// are gated by the UI, so they are programming errors, not UX branches).
  Future<void> editSong(
    Song song, {
    String? title,
    String? album,
    String? artist,
    Uint8List? coverBytes,
  }) async {
    final String? path = song.path;
    if (path == null || path.isEmpty) {
      throw StateError('song ${song.id} has no server path');
    }
    if (title == null &&
        album == null &&
        artist == null &&
        coverBytes == null) {
      throw StateError('editSong called with nothing to change');
    }

    final BackendService service =
        await ref.read(backendServiceProvider.future);
    await service.editLibrarySong(
      path: path,
      title: title,
      album: album,
      artist: artist,
      coverBytes: coverBytes,
    );

    if (coverBytes != null) {
      await _evictCover(song);
    }

    ref.invalidate(librarySearchProvider);
    ref.invalidate(libraryAlbumsProvider);
    ref.invalidate(libraryArtistsProvider);
    final String? albumId = song.albumId;
    if (albumId != null) ref.invalidate(libraryAlbumProvider(albumId));
    ref.invalidate(downloadedSongsProvider);
    // Home redesign: the newest-albums section (and its See-all screen) +
    // Favorites replace the old recent/frequent/random Home providers.
    ref.invalidate(homeNewestProvider);
    ref.invalidate(recentlyAddedFullProvider);
    ref.invalidate(starredSongsProvider);
  }

  /// Drop the cached cover JPG for the song's `coverArt` id and clear the
  /// decoded-image cache so the next render re-fetches from Subsonic. Failures
  /// are swallowed — a stale cover is a cosmetic issue, not a reason to fail
  /// the whole edit after the tags already wrote.
  Future<void> _evictCover(Song song) async {
    final String? coverArtId = song.coverArt;
    if (coverArtId != null && coverArtId.isNotEmpty) {
      try {
        final OfflinePaths paths =
            await ref.read(offlinePathsProvider.future);
        final ServerCreds creds = ref.read(serverCredsProvider);
        final File? file = paths.coverFile(creds, coverArtId);
        if (file != null && file.existsSync()) file.deleteSync();
      } catch (_) {
        // best-effort eviction
      }
    }
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }
}
