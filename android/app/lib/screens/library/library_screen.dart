import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_error.dart';
import '../../models/search_response.dart';
import '../../models/search_result_item.dart';
import '../../models/seed_track.dart';
import '../../models/subsonic/album.dart';
import '../../models/subsonic/artist.dart';
import '../../models/subsonic/playlist.dart';
import '../../models/subsonic/search_result3.dart';
import '../../models/subsonic/song.dart';
import '../../offline/offline_manifest.dart';
import '../../player/playback_actions.dart';
import '../../player/player_provider.dart';
import '../../providers/download.dart';
import '../../providers/download_to_playlist.dart';
import '../../providers/library/combined_search.dart';
import '../../providers/library/favourites.dart';
import '../../providers/library/library_filters.dart';
import '../../providers/library/library_search_query.dart';
import '../../providers/library/library_views.dart';
import '../../providers/library/most_played_artists.dart';
import '../../providers/library/playlist_mutations.dart';
import '../../router.dart';
import '../../theme.dart';
import '../../widgets/add_to_playlist_sheet.dart';
import '../../widgets/alphabet_scrubber.dart';
import '../../widgets/branded_header.dart';
import '../../widgets/gradient_tab_indicator.dart';
import '../../widgets/library_cover_art.dart';
import '../../widgets/library_filter_chips.dart';
import '../../widgets/download_to_playlist_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_snackbar.dart';
import '../../widgets/library_result_tile.dart';
import '../../widgets/playlist_dialogs.dart';
import '../../widgets/result_tile.dart';
import '../../widgets/skeleton.dart';
import 'album_grid_card.dart';
import 'playlist_grid_card.dart';

// A17: search-mode + browse-tab private widgets live in sibling part files to
// keep this screen file readable. They share this library's imports + privacy.
part 'library_search_results.dart';
part 'library_tabs.dart';

/// Library tab — 2026-07 redesign (docs/LIBRARYSCREEN.md). When idle, shows
/// the shared branded header, a "Your Library" headline and segmented tabs
/// of Albums / Artists / Playlists driven by Subsonic. When the user enters
/// search mode (search icon in the AppBar), the tab UI is hidden and the
/// combined-search results render: "In your library" (Subsonic search3)
/// above "Online results" (heerr backend search, auto-fired on empty
/// library or manually).
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({this.initialTabIndex = 0, super.key});

  /// Which sub-tab (0=Albums, 1=Artists, 2=Playlists — X1 mockup order) to
  /// open on. Set via the `/library?tab=` query param (Phase Z Profile
  /// "Playlists" deep link) — see `_tabIndexFor` in router.dart.
  final int initialTabIndex;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    final String initial = ref.read(librarySearchQueryProvider);
    _searchController = TextEditingController(text: initial);
    final bool autoFocusRequested =
        ref.read(librarySearchAutoFocusProvider);
    // V1: search mode is owned by `librarySearchActiveProvider` (the single
    // source of truth, also read by the shell's back-button handler). Seed it
    // from the persisted query / auto-focus request post-frame so we don't
    // mutate a provider during initState/build.
    final bool initialSearching = initial.isNotEmpty || autoFocusRequested;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(librarySearchActiveProvider.notifier).set(initialSearching);
    });
    if (autoFocusRequested) {
      // Consume after the first build so subsequent navigations into the
      // Library tab don't accidentally re-enter search mode.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(librarySearchAutoFocusProvider.notifier).consume();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _enterSearch() {
    ref.read(librarySearchActiveProvider.notifier).set(true);
  }

  void _exitSearch() {
    // Flipping the provider drives the rebuild back to browse; the listener in
    // `build` clears the controller + query on the true→false transition (so
    // the shell's PopScope can exit search by flipping the same flag).
    ref.read(librarySearchActiveProvider.notifier).set(false);
  }

  void _onQueryChanged(String value) {
    ref.read(librarySearchQueryProvider.notifier).set(value);
  }

  @override
  Widget build(BuildContext context) {
    // Clear the field + query whenever search mode turns off — whether exited
    // via the in-app back arrow (_exitSearch) or the system back button
    // (shell PopScope flips the same provider).
    ref.listen<bool>(librarySearchActiveProvider, (bool? prev, bool next) {
      if (prev == true && !next) {
        _searchController.clear();
        ref.read(librarySearchQueryProvider.notifier).clear();
      }
    });
    final bool searching = ref.watch(librarySearchActiveProvider);
    if (searching) {
      return _SearchModeScaffold(
        controller: _searchController,
        onQueryChanged: _onQueryChanged,
        onExit: _exitSearch,
      );
    }
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTabIndex,
      child: Scaffold(
        appBar: BrandedAppBar(
          compactGreeting: true,
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search',
              onPressed: _enterSearch,
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                'Your Library',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            const _LibrarySegmentedTabs(),
            const Expanded(
              child: TabBarView(
                children: <Widget>[
                  _AlbumsTab(),
                  _ArtistsTab(),
                  _PlaylistsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Segmented tab row per the mockup: icon + label per tab, active tab in
/// magenta over the gradient underline indicator (shared with the detail
/// screens' TabBar styling).
class _LibrarySegmentedTabs extends StatelessWidget {
  const _LibrarySegmentedTabs();

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return TabBar(
      indicator: const GradientTabIndicator(),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelColor: heerrMagenta,
      unselectedLabelColor: cs.onSurfaceVariant,
      tabs: const <Tab>[
        Tab(
          height: 46,
          child: _SegmentedTabLabel(
            icon: Icons.album_outlined,
            label: 'Albums',
          ),
        ),
        Tab(
          height: 46,
          child: _SegmentedTabLabel(
            icon: Icons.person_outline,
            label: 'Artists',
          ),
        ),
        Tab(
          height: 46,
          child: _SegmentedTabLabel(
            icon: Icons.queue_music_outlined,
            label: 'Playlists',
          ),
        ),
      ],
    );
  }
}

class _SegmentedTabLabel extends StatelessWidget {
  const _SegmentedTabLabel({required this.icon, required this.label});

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
