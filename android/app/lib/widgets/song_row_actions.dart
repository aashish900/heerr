import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../models/subsonic/song.dart';
import '../providers/library/favourites.dart';
import '../providers/library/playlist_mutations.dart';
import 'add_to_playlist_sheet.dart';
import 'error_snackbar.dart';

/// Per-song trailing action cluster used by album-detail and
/// playlist-detail song rows. Renders a Row with:
///   1. Favourites heart (outlined → filled red when the song is in the
///      Favourites playlist). Tap toggles membership via
///      `PlaylistMutations.toggleFavourite`. Lazy-creates the
///      "Favourites" playlist on first ever tap.
///   2. "Add to playlist…" `more_vert` button → opens
///      [AddToPlaylistSheet] with this song's id (visible discoverable
///      alternative to the M3 long-press affordance).
///   3. Optional [trailingStatus] icon (now-playing, offline state,
///      scheduled badge) appended to the right of the actions.
class SongRowActions extends ConsumerWidget {
  const SongRowActions({
    required this.song,
    this.trailingStatus,
    super.key,
  });

  final Song song;

  /// Existing trailing widget (now-playing indicator / offline-state
  /// glyph / scheduled badge) appended after the action buttons. Null
  /// when the row has no status to show.
  final Widget? trailingStatus;

  Future<void> _onToggleFavourite(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(playlistMutationsProvider.notifier)
          .toggleFavourite(song);
    } on ApiError catch (e) {
      if (!context.mounted) return;
      showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Set<String> favIds = ref
            .watch(favouriteSongIdsProvider)
            .valueOrNull ??
        const <String>{};
    final bool isFav = favIds.contains(song.id);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(
            isFav ? Icons.favorite : Icons.favorite_border,
            // Red border + fill when in Favourites, default colour
            // (onSurfaceVariant) when not.
            color: isFav ? Colors.redAccent : null,
          ),
          tooltip:
              isFav ? 'Remove from Favourites' : 'Add to Favourites',
          onPressed: () => _onToggleFavourite(context, ref),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.more_vert),
          tooltip: 'Add to playlist…',
          onPressed: () => AddToPlaylistSheet.show(
            context: context,
            songIds: <String>[song.id],
          ),
        ),
        if (trailingStatus != null) ...<Widget>[
          const SizedBox(width: 4),
          trailingStatus!,
        ],
      ],
    );
  }
}
