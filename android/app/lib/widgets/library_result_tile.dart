import 'package:flutter/material.dart';

import '../theme.dart';
import 'library_cover_art.dart';

/// One row in a Library list (Artists / Albums / Playlists). Mirrors the
/// shape of `ResultTile` (YouTube-Music search results) but talks to the
/// Subsonic side — cover art comes from `coverArtId` via [LibraryCoverArt]
/// and the tile is always tappable (no "already downloaded" dim).
///
/// Trailing slot precedence (highest first):
///   1. `isCurrentlyPlaying` → green play_arrow (the now-playing indicator).
///   2. `onMarkToggle != null` → outlined or filled `download_for_offline`
///      icon, driven by `isMarkedForOffline`. Used by Album/Playlist detail
///      rows + browse tiles for the offline feature (Phase L).
///   3. `trailingPlay` → outline play icon, calling `onPlay`.
///   4. nothing.
///
/// When `offlineProgress` is non-null, a thin LinearProgressIndicator is
/// rendered under the subtitle — the per-song download progress for the
/// offline feature.
class LibraryResultTile extends StatelessWidget {
  const LibraryResultTile({
    required this.title,
    required this.subtitle,
    required this.coverArtId,
    required this.onTap,
    this.trailingPlay = false,
    this.onPlay,
    this.isCurrentlyPlaying = false,
    this.isMarkedForOffline = false,
    this.onMarkToggle,
    this.offlineProgress,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? coverArtId;
  final VoidCallback onTap;
  final bool trailingPlay;
  final VoidCallback? onPlay;
  final bool isCurrentlyPlaying;

  /// Whether this album / playlist is currently marked for offline sync.
  /// Drives the filled-vs-outline state of the trailing download icon.
  final bool isMarkedForOffline;

  /// When non-null, the trailing slot becomes the offline-download toggle
  /// (subject to `isCurrentlyPlaying` winning). Setting this without an
  /// onTap doesn't make sense — leave null on tiles that aren't markable.
  final VoidCallback? onMarkToggle;

  /// In-flight per-song download progress, 0.0..1.0. Renders a thin
  /// LinearProgressIndicator under the subtitle. Null = no bar.
  final double? offlineProgress;

  @override
  Widget build(BuildContext context) {
    final Widget? trailing;
    if (isCurrentlyPlaying) {
      trailing = const Icon(Icons.play_arrow, color: heerrGreen);
    } else if (onMarkToggle != null) {
      trailing = IconButton(
        icon: Icon(
          isMarkedForOffline
              ? Icons.download_for_offline
              : Icons.download_for_offline_outlined,
          color: isMarkedForOffline ? heerrGreen : null,
        ),
        onPressed: onMarkToggle,
        tooltip: isMarkedForOffline ? 'Unmark for offline' : 'Mark for offline',
      );
    } else if (trailingPlay) {
      // Browse-tab tiles: passive marker badge to the left of the play
      // button when the album/playlist is marked but the toggle isn't
      // wired up here (the toggle lives on the detail screen's AppBar).
      if (isMarkedForOffline) {
        trailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(
                Icons.download_for_offline,
                color: heerrGreen,
                size: 18,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.play_arrow_outlined),
              onPressed: onPlay,
              tooltip: 'Play all',
            ),
          ],
        );
      } else {
        trailing = IconButton(
          icon: const Icon(Icons.play_arrow_outlined),
          onPressed: onPlay,
          tooltip: 'Play all',
        );
      }
    } else if (isMarkedForOffline) {
      // No play button, no toggle, but tile is marked — show passive badge.
      trailing = const Icon(
        Icons.download_for_offline,
        color: heerrGreen,
        size: 18,
      );
    } else {
      trailing = null;
    }

    final Widget? subtitleWidget = subtitle == null
        ? null
        : Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );

    final Widget? subtitleWithProgress;
    if (offlineProgress != null) {
      subtitleWithProgress = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ?subtitleWidget,
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: LinearProgressIndicator(
              value: offlineProgress!.clamp(0.0, 1.0),
              minHeight: 2,
            ),
          ),
        ],
      );
    } else {
      subtitleWithProgress = subtitleWidget;
    }

    return ListTile(
      leading: LibraryCoverArt(coverArtId: coverArtId),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isCurrentlyPlaying
            ? const TextStyle(color: heerrGreen, fontWeight: FontWeight.w600)
            : null,
      ),
      subtitle: subtitleWithProgress,
      trailing: trailing,
      onTap: onTap,
    );
  }
}
