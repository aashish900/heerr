import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/subsonic/song.dart';
import '../../providers/downloaded_songs.dart';
import '../../router.dart' show Routes;
import '../../widgets/gradient_icon.dart';

/// "Quick Access" shortcut row (mockup zone 5 — HOMESCREEN.md task 3).
/// Static 3 cards (Favorites, Offline, Recently Added); the mockup's "Edit"
/// customization is deferred (DEBT). The For You card was dropped once For You
/// got its own Home section (its See all opens the same screen).
/// Horizontally scrollable at readable card size.
class QuickAccessRow extends ConsumerWidget {
  const QuickAccessRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Offline card subtitle: live count of ready downloaded songs. Local
    // disk state, not network — loading/error just fall back to a label.
    final AsyncValue<List<Song>> downloaded =
        ref.watch(downloadedSongsProvider);
    final String offlineSubtitle = downloaded.when(
      data: (List<Song> songs) =>
          '${songs.length} ${songs.length == 1 ? 'song' : 'songs'}',
      loading: () => 'Downloads',
      error: (_, _) => 'Downloads',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Text(
            'Quick Access',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: <Widget>[
              _QuickAccessCard(
                key: const Key('quick-access-favorites'),
                icon: Icons.favorite_outline,
                title: 'Favorites',
                subtitle: 'Loved songs',
                onTap: () => context.push(Routes.libraryFavorites),
              ),
              const SizedBox(width: 12),
              _QuickAccessCard(
                key: const Key('quick-access-offline'),
                icon: Icons.download_outlined,
                title: 'Offline',
                subtitle: offlineSubtitle,
                onTap: () => context.go(Routes.downloads),
              ),
              const SizedBox(width: 12),
              _QuickAccessCard(
                key: const Key('quick-access-recently-added'),
                icon: Icons.schedule_outlined,
                title: 'Recently Added',
                subtitle: 'New music',
                onTap: () => context.push(Routes.libraryRecentlyAdded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: cs.outline),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              GradientIcon(child: Icon(icon, size: 28, color: Colors.white)),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
