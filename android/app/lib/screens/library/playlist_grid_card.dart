import 'package:flutter/material.dart';

import '../../models/subsonic/playlist.dart';
import '../../theme.dart';
import '../../widgets/library_cover_art.dart';

/// One cell of the Playlists-tab 2-column grid (X6, LIBRARYSCREEN.md §1):
/// cover with a dark bottom gradient, title, "by `<owner>`", song count.
class PlaylistGridCard extends StatelessWidget {
  const PlaylistGridCard({required this.playlist, this.onTap, super.key});

  final Playlist playlist;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _GridCardShell(
      key: Key('playlist-grid-card-${playlist.id}'),
      onTap: onTap,
      background: LayoutBuilder(
        builder: (BuildContext c, BoxConstraints constraints) =>
            LibraryCoverArt(
          coverArtId: playlist.coverArt,
          size: constraints.maxWidth,
          borderRadius: 0,
        ),
      ),
      title: playlist.name,
      subtitleLines: <String>[
        if (playlist.owner != null) 'by ${playlist.owner}',
        if (playlist.songCount != null) '${playlist.songCount} songs',
      ],
    );
  }
}

/// The leading Favorites card — starred songs presented as a playlist-like
/// tile with a heart, per the mockup.
class FavoritesGridCard extends StatelessWidget {
  const FavoritesGridCard({required this.songCount, this.onTap, super.key});

  /// Null while the starred fetch is unresolved — the count line is omitted.
  final int? songCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _GridCardShell(
      key: const Key('favorites-grid-card'),
      onTap: onTap,
      background: const DecoratedBox(
        decoration: BoxDecoration(gradient: heerrGradient),
        child: Center(
          child: Icon(Icons.favorite, size: 48, color: Colors.black54),
        ),
      ),
      title: 'Favorites',
      subtitleLines: <String>[
        if (songCount != null) '$songCount songs',
      ],
    );
  }
}

/// The trailing "+ Create Playlist" card — replaces the old FAB (X6).
class CreatePlaylistGridCard extends StatelessWidget {
  const CreatePlaylistGridCard({this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      key: const Key('create-playlist-card'),
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ShaderMask(
              shaderCallback: (Rect bounds) =>
                  heerrGradient.createShader(bounds),
              child: const Icon(Icons.add, size: 36, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Create Playlist',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared card chrome: rounded clip, full-bleed background, dark bottom
/// gradient with the text block over it.
class _GridCardShell extends StatelessWidget {
  const _GridCardShell({
    required this.background,
    required this.title,
    required this.subtitleLines,
    this.onTap,
    super.key,
  });

  final Widget background;
  final String title;
  final List<String> subtitleLines;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    return Material(
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            background,
            // Legibility gradient behind the text block.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black87,
                  ],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  for (final String line in subtitleLines)
                    Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          tt.bodySmall?.copyWith(color: Colors.white70),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
