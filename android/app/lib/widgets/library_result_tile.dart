import 'package:flutter/material.dart';

import 'library_cover_art.dart';

/// One row in a Library list (Artists / Albums / Playlists). Mirrors the
/// shape of `ResultTile` (YouTube-Music search results) but talks to the
/// Subsonic side — cover art comes from `coverArtId` via [LibraryCoverArt]
/// and the tile is always tappable (no "already downloaded" dim).
///
/// `trailingPlay`, when true, renders an outline play icon as a secondary
/// affordance. The play action is wired at J2 (currently `onPlay` is a
/// no-op placeholder for I1); the tap on the row body always navigates to
/// the detail screen via [onTap].
class LibraryResultTile extends StatelessWidget {
  const LibraryResultTile({
    required this.title,
    required this.subtitle,
    required this.coverArtId,
    required this.onTap,
    this.trailingPlay = false,
    this.onPlay,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? coverArtId;
  final VoidCallback onTap;
  final bool trailingPlay;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: LibraryCoverArt(coverArtId: coverArtId),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: trailingPlay
          ? IconButton(
              icon: const Icon(Icons.play_arrow_outlined),
              onPressed: onPlay,
              tooltip: 'Play all',
            )
          : null,
      onTap: onTap,
    );
  }
}
