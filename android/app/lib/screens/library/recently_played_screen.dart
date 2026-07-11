import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/subsonic/album.dart';
import '../../providers/home/home_providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton.dart';
import '../home/recently_added_section.dart';

/// "Recently Played" list — Profile screen's "My Music" row destination
/// (Phase Z redesign). Mirrors [RecentlyAddedScreen] but sources
/// `type=recent` (played, not added) via [recentlyPlayedProvider].
class RecentlyPlayedScreen extends ConsumerWidget {
  const RecentlyPlayedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Album>> recent = ref.watch(recentlyPlayedProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recently Played')),
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(recentlyPlayedProvider);
          return ref
              .read(recentlyPlayedProvider.future)
              .catchError((_) => const <Album>[]);
        },
        child: recent.when(
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
                      const Text("Can't load recently played"),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        key: const Key('recently-played-retry'),
                        onPressed: () =>
                            ref.invalidate(recentlyPlayedProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          data: (List<Album> albums) {
            if (albums.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const <Widget>[
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 96),
                    child: EmptyState(
                      icon: Icons.history,
                      title: 'Nothing played yet',
                      subtitle: 'Albums you play will show up here.',
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: albums.length,
              itemBuilder: (BuildContext c, int i) =>
                  RecentlyAddedRow(album: albums[i]),
            );
          },
        ),
      ),
    );
  }
}
