import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/subsonic/album.dart';
import '../../providers/home/home_providers.dart';
import '../../router.dart' show Routes;
import '../../widgets/library_cover_art.dart';
import '../../widgets/skeleton.dart';

/// "Recently Added" vertical section (mockup zone 6 — HOMESCREEN.md task 4).
/// First 5 newest albums as plain rows inside the parent ListView (no nested
/// scrollable); "See all" pushes the full-screen list. The mockup's per-row
/// kebab menu is deferred (DEBT) — row tap → album detail covers the need.
class RecentlyAddedSection extends ConsumerWidget {
  const RecentlyAddedSection({super.key});

  static const int _kMaxRows = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Album>> newest = ref.watch(homeNewestProvider);
    return newest.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: <Widget>[SkeletonTile(), SkeletonTile(), SkeletonTile()],
        ),
      ),
      error: (Object e, _) => const SizedBox.shrink(),
      data: (List<Album> albums) {
        if (albums.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Recently Added',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    key: const Key('recently-added-see-all'),
                    onPressed: () =>
                        context.push(Routes.libraryRecentlyAdded),
                    child: const Text('See all'),
                  ),
                ],
              ),
            ),
            for (final Album a in albums.take(_kMaxRows))
              RecentlyAddedRow(album: a),
          ],
        );
      },
    );
  }
}

/// One recently-added album row: 56px cover, bold title, grey artist.
/// Shared by the Home section and the full RecentlyAddedScreen.
class RecentlyAddedRow extends StatelessWidget {
  const RecentlyAddedRow({required this.album, super.key});

  final Album album;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    final ColorScheme cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: LibraryCoverArt(coverArtId: album.coverArt, borderRadius: 8),
      title: Text(
        album.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: album.artist == null
          ? null
          : Text(
              album.artist!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
      onTap: () => context.push(Routes.libraryAlbum(album.id)),
    );
  }
}
