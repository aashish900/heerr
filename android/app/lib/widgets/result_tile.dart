import 'package:flutter/material.dart';

import '../models/search_result_item.dart';

/// One row in the Search screen's results list. Dims when the backend hint
/// says the track is already downloaded.
class ResultTile extends StatelessWidget {
  const ResultTile({required this.item, super.key});

  final SearchResultItem item;

  String _subtitle() {
    final String? album = item.album;
    if (album != null && album.isNotEmpty) {
      return '${item.artist} • $album';
    }
    return item.artist;
  }

  @override
  Widget build(BuildContext context) {
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
        // Download dispatch lives at milestone D1. Until then the trailing
        // slot shows an icon only when the backend says we already have the
        // track on disk.
        trailing: item.alreadyDownloaded
            ? const Icon(Icons.download_done)
            : null,
      ),
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
