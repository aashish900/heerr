import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/search_result_item.dart';
import '../providers/download.dart';

/// One row in the Search screen's results list. Dims when the backend hint
/// says the track is already downloaded.
///
/// Tapping anywhere on the row invokes [onPreview] (stream-first listen).
/// The trailing slot is a row: an optional Preview (play) button followed by a
/// download-status icon with three states:
///   * `inFlight` (a POST /download for this URI is mid-flight) → spinner.
///   * `item.alreadyDownloaded` → check-mark badge.
///   * otherwise → tappable download icon that invokes [onDownload].
///
/// [onDownload] is disabled when the row is mid-flight or already downloaded.
/// [onPreview], when set, renders a play button AND makes the whole row
/// tappable — independent of download state. [onLongPress], when set, fires on
/// a long-press of the row (used to offer "download to a playlist"). The parent
/// screen owns the dispatch + snackbar; the tile is presentational.
class ResultTile extends ConsumerWidget {
  const ResultTile({
    required this.item,
    this.onDownload,
    this.onPreview,
    this.onLongPress,
    super.key,
  });

  final SearchResultItem item;
  final VoidCallback? onDownload;
  final VoidCallback? onPreview;
  final VoidCallback? onLongPress;

  String _subtitle() {
    final String? album = item.album;
    if (album != null && album.isNotEmpty) {
      return '${item.artist} • $album';
    }
    return item.artist;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool inFlight = ref.watch(
      downloadDispatcherProvider.select(
        (Set<String> s) => s.contains(item.sourceUrl),
      ),
    );
    final bool downloadable =
        onDownload != null && !inFlight && !item.alreadyDownloaded;

    return Opacity(
      opacity: item.alreadyDownloaded ? 0.5 : 1.0,
      child: ListTile(
        leading: _Cover(url: item.coverUrl),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _subtitle(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (onPreview != null)
              IconButton(
                icon: const Icon(Icons.play_circle_outline),
                tooltip: 'Preview',
                onPressed: onPreview,
              ),
            _Trailing(
              alreadyDownloaded: item.alreadyDownloaded,
              inFlight: inFlight,
              onDownload: downloadable ? onDownload : null,
            ),
          ],
        ),
        onTap: onPreview,
        onLongPress: onLongPress,
      ),
    );
  }
}

class _Trailing extends StatelessWidget {
  const _Trailing({
    required this.alreadyDownloaded,
    required this.inFlight,
    this.onDownload,
  });

  final bool alreadyDownloaded;
  final bool inFlight;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    if (inFlight) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (alreadyDownloaded) {
      return const Icon(Icons.download_done);
    }
    return IconButton(
      icon: const Icon(Icons.download_outlined),
      tooltip: 'Download',
      onPressed: onDownload,
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    const double size = 56;
    final String? u = url;
    if (u == null || u.isEmpty) {
      return _placeholder(context, size);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        u,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (BuildContext c, _, _) => _placeholder(c, size),
      ),
    );
  }

  Widget _placeholder(BuildContext context, double size) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(Icons.music_note, color: cs.onSurfaceVariant),
    );
  }
}
