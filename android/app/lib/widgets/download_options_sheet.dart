import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../models/search_result_item.dart';
import '../models/subsonic/playlist.dart';
import '../providers/library/library_playlists.dart';
import '../providers/server_creds.dart';

/// Modal bottom sheet shown when the user taps the download icon on a
/// YouTube-Music search result (U1). Lets the user either download the song
/// directly (current behaviour) or download AND queue it to be added to one of
/// their Navidrome playlists once the job finishes and Navidrome indexes the
/// file.
///
/// Purely presentational — it owns no async logic. The two outcomes are
/// surfaced as callbacks the caller wires to [downloadDispatcherProvider]
/// (download-only) and `downloadAndAddToPlaylist` (download-to-playlist):
///   - [onDownloadOnly] — fired by the "Download" row.
///   - [onDownloadToPlaylist] — fired by a playlist row, with that playlist's
///     id + name.
///
/// Each row pops the sheet *first* (so the sheet's context is gone before the
/// caller starts showing snackbars on the host scaffold), then invokes the
/// callback.
class DownloadOptionsSheet extends ConsumerWidget {
  const DownloadOptionsSheet({
    required this.item,
    required this.onDownloadOnly,
    required this.onDownloadToPlaylist,
    super.key,
  });

  final SearchResultItem item;
  final VoidCallback onDownloadOnly;
  final void Function(String playlistId, String playlistName)
      onDownloadToPlaylist;

  static void show({
    required BuildContext context,
    required SearchResultItem item,
    required VoidCallback onDownloadOnly,
    required void Function(String playlistId, String playlistName)
        onDownloadToPlaylist,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DownloadOptionsSheet(
        item: item,
        onDownloadOnly: onDownloadOnly,
        onDownloadToPlaylist: onDownloadToPlaylist,
      ),
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                item.title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ListTile(
              key: const Key('download-options-download-only'),
              leading: const Icon(Icons.download_outlined),
              title: const Text('Download'),
              onTap: () {
                Navigator.of(context).pop();
                onDownloadOnly();
              },
            ),
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('Add to playlist after download'),
            ),
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
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 24),
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
                          onDownloadToPlaylist(p.id, p.name);
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
