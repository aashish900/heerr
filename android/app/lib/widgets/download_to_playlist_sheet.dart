import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../models/search_result_item.dart';
import '../models/subsonic/playlist.dart';
import '../providers/library/library_playlists.dart';
import '../providers/server_creds.dart';

/// Modal bottom sheet shown when the user long-presses a YouTube-Music search
/// result (U1). It lets them pick one of their Navidrome playlists; the caller
/// then downloads the song and adds it to that playlist once the job finishes
/// and Navidrome indexes the file. A plain tap on the row's download icon still
/// downloads directly — this sheet is the opt-in "to a playlist" path only.
///
/// Purely presentational — it owns no async logic. Tapping a playlist row pops
/// the sheet *first* (so the sheet's context is gone before the caller starts
/// showing snackbars on the host scaffold), then invokes [onSelect] with that
/// playlist's id + name.
class DownloadToPlaylistSheet extends ConsumerWidget {
  const DownloadToPlaylistSheet({
    required this.item,
    required this.onSelect,
    super.key,
  });

  final SearchResultItem item;
  final void Function(String playlistId, String playlistName) onSelect;

  static void show({
    required BuildContext context,
    required SearchResultItem item,
    required void Function(String playlistId, String playlistName) onSelect,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DownloadToPlaylistSheet(item: item, onSelect: onSelect),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Playlist>> playlistsAsync =
        ref.watch(libraryPlaylistsProvider);
    final ServerCreds creds = ref.watch(serverCredsProvider);
    final String? username = creds.navidromeUsername;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                'Download to playlist',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                item.title,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: playlistsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (Object e, _) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Text(
                    e is ApiError ? e.message : 'Error: $e',
                  ),
                ),
                data: (List<Playlist> all) {
                  final List<Playlist> editable = <Playlist>[
                    for (final Playlist p in all)
                      if (p.owner != null &&
                          username != null &&
                          p.owner == username)
                        p,
                  ];
                  if (editable.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Text('No playlists yet.'),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: editable.length,
                    itemBuilder: (BuildContext c, int i) {
                      final Playlist p = editable[i];
                      return ListTile(
                        key: Key('download-to-playlist-${p.id}'),
                        leading: const Icon(Icons.queue_music_outlined),
                        title: Text(p.name),
                        subtitle: p.songCount == null
                            ? null
                            : Text('${p.songCount} songs'),
                        onTap: () {
                          Navigator.of(context).pop();
                          onSelect(p.id, p.name);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
