import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import 'podcast_shows_grid.dart';

/// PC3 (#53): the calling user's subscribed channels, standalone entry
/// point (reached from Profile). PR1 (#53) extracted the grid itself into
/// [PodcastShowsGrid] so the same content also renders inside the Library
/// "Podcasts > Shows" tab — this screen is now a thin Scaffold wrapper.
class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Podcasts'),
        actions: <Widget>[
          IconButton(
            key: const Key('podcasts-discover-action'),
            icon: const Icon(Icons.add),
            tooltip: 'Discover podcasts',
            onPressed: () => context.push(Routes.podcastsDiscover),
          ),
        ],
      ),
      body: const PodcastShowsGrid(),
    );
  }
}
