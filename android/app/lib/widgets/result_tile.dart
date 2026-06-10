import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/search_result_item.dart';
import '../providers/download.dart';

/// One row in the Search screen's results list. Dims when the backend hint
/// says the track is already downloaded.
///
/// The trailing slot has three states:
///   * `inFlight` (a POST /download for this URI is mid-flight) → spinner.
///   * `item.alreadyDownloaded` → check-mark badge.
///   * otherwise → outline download icon to signal tap-to-queue.
///
/// `onTap` is invoked when the row is tapped. It's disabled (null) when the
/// row is mid-flight or already downloaded — the parent screen owns the
/// dispatch + snackbar; the tile is presentational.
class ResultTile extends ConsumerWidget {
  const ResultTile({required this.item, this.onTap, super.key});

  final SearchResultItem item;
  final VoidCallback? onTap;

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
    final bool tappable =
        onTap != null && !inFlight && !item.alreadyDownloaded;

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
        trailing: _Trailing(
          alreadyDownloaded: item.alreadyDownloaded,
          inFlight: inFlight,
        ),
        onTap: tappable ? onTap : null,
      ),
    );
  }
}

class _Trailing extends StatelessWidget {
  const _Trailing({required this.alreadyDownloaded, required this.inFlight});

  final bool alreadyDownloaded;
  final bool inFlight;

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
    return const Icon(Icons.download_outlined);
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
