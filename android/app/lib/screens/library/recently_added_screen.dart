import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/subsonic/album.dart';
import '../../providers/home/home_providers.dart';
import '../../widgets/skeleton.dart';
import '../home/recently_added_section.dart';

/// Full "Recently Added" list — the Home section's "See all" target
/// (HOMESCREEN.md task 4). 50 newest albums, pull-to-refresh.
class RecentlyAddedScreen extends ConsumerWidget {
  const RecentlyAddedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Album>> newest =
        ref.watch(recentlyAddedFullProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recently Added')),
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(recentlyAddedFullProvider);
          return ref
              .read(recentlyAddedFullProvider.future)
              .catchError((_) => const <Album>[]);
        },
        child: newest.when(
          loading: () => ListView(
            children: const <Widget>[
              SkeletonTile(),
              SkeletonTile(),
              SkeletonTile(),
              SkeletonTile(),
              SkeletonTile(),
            ],
          ),
          error: (Object e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: <Widget>[
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.wifi_off_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      const Text("Can't load recently added"),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        key: const Key('recently-added-retry'),
                        onPressed: () =>
                            ref.invalidate(recentlyAddedFullProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          data: (List<Album> albums) => ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: albums.length,
            itemBuilder: (BuildContext c, int i) =>
                RecentlyAddedRow(album: albums[i]),
          ),
        ),
      ),
    );
  }
}
