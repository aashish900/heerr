import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_error.dart';
import '../../models/subsonic/album.dart';
import '../../models/subsonic/playlist.dart';
import '../../models/subsonic/song.dart';
import '../../offline/offline_manifest.dart';
import '../../offline/offline_marker.dart';
import '../../player/playback_actions.dart';
import '../../providers/downloads_filters.dart';
import '../../providers/downloads_views.dart';
import '../../providers/library/library_delete.dart';
import '../../router.dart';
import '../../theme.dart';
import '../../widgets/branded_header.dart';
import '../../widgets/error_snackbar.dart';
import '../../widgets/gradient_icon.dart';
import '../../widgets/gradient_tab_indicator.dart';
import '../../widgets/library_cover_art.dart';
import '../../widgets/library_result_tile.dart';
import 'downloads_filter_chips.dart';
import 'quick_action_cards.dart';
import 'server_status_card.dart';
import 'storage_card.dart';
import 'sync_activity_section.dart';

part 'downloads_tabs.dart';

/// Downloads tab — "Sync Center" redesign (docs/DOWNLOADSSCREEN.md, DL1).
/// Header + "Downloads" headline sit above a pinned segmented tab bar
/// (Songs / Albums / Playlists — D3: Songs first, this screen's primary
/// intent). Later DL tasks (DL2-DL7) insert the server-status hero, quick
/// actions, sync-activity and storage sections between the headline and the
/// tab bar as additional header slivers.
class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BrandedAppBar(compactGreeting: true),
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            const SliverToBoxAdapter(child: _DownloadsTitle()),
            const SliverToBoxAdapter(child: ServerStatusCard()),
            const SliverToBoxAdapter(child: QuickActionCards()),
            const SliverToBoxAdapter(child: SyncActivitySection()),
            SliverPersistentHeader(
              pinned: true,
              delegate: _DownloadsTabBarDelegate(tabs: _tabs),
            ),
            SliverToBoxAdapter(
              child: AnimatedBuilder(
                animation: _tabs,
                builder: (BuildContext context, _) => DownloadsFilterChips(
                  tab: DownloadsTab.values[_tabs.index],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabs,
          children: const <Widget>[_SongsTab(), _AlbumsTab(), _PlaylistsTab()],
        ),
      ),
    );
  }
}

class _DownloadsTitle extends StatelessWidget {
  const _DownloadsTitle();

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Downloads',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your music, available everywhere.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

/// Segmented tab row matching Library's visual (`_LibrarySegmentedTabs`,
/// `library_screen.dart`), pinned so it stays visible while the hero/quick
/// action/sync-activity sections above it scroll away.
class _DownloadsTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _DownloadsTabBarDelegate({required this.tabs});

  final TabController tabs;

  static const double _height = 46;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: TabBar(
        controller: tabs,
        indicator: const GradientTabIndicator(),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: heerrMagenta,
        unselectedLabelColor: cs.onSurfaceVariant,
        tabs: const <Tab>[
          Tab(
            height: _height,
            child: _DownloadsTabLabel(
              icon: Icons.music_note_outlined,
              label: 'Songs',
            ),
          ),
          Tab(
            height: _height,
            child: _DownloadsTabLabel(
              icon: Icons.album_outlined,
              label: 'Albums',
            ),
          ),
          Tab(
            height: _height,
            child: _DownloadsTabLabel(
              icon: Icons.queue_music_outlined,
              label: 'Playlists',
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DownloadsTabBarDelegate oldDelegate) =>
      oldDelegate.tabs != tabs;
}

class _DownloadsTabLabel extends StatelessWidget {
  const _DownloadsTabLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}
