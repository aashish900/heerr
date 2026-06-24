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
import '../../models/subsonic/artist_index.dart';
import '../../models/subsonic/playlist.dart';
import '../../models/subsonic/search_result3.dart';
import '../../models/subsonic/song.dart';
import '../../offline/offline_manifest.dart';
import '../../player/playback_actions.dart';
import '../../player/player_provider.dart';
import '../../providers/download.dart';
import '../../providers/download_to_playlist.dart';
import '../../providers/library/combined_search.dart';
import '../../providers/library/library_albums.dart';
import '../../providers/library/library_artists.dart';
import '../../providers/library/library_playlists.dart';
import '../../providers/library/library_search_query.dart';
import '../../providers/library/playlist_mutations.dart';
import '../../router.dart';
import '../../widgets/add_to_playlist_sheet.dart';
import '../../widgets/download_to_playlist_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_snackbar.dart';
import '../../widgets/library_result_tile.dart';
import '../../widgets/playlist_dialogs.dart';
import '../../widgets/result_tile.dart';
import '../../widgets/skeleton.dart';

// A17: search-mode + browse-tab private widgets live in sibling part files to
// keep this screen file readable. They share this library's imports + privacy.
part 'library_search_results.dart';
part 'library_tabs.dart';

/// Library tab — when idle, shows a `TabBar` of Artists / Albums / Playlists
/// driven by Subsonic. When the user enters search mode (search icon in the
/// AppBar), the tab UI is hidden and the combined-search results render:
/// "In your library" (Subsonic search3) above "On YouTube Music" (heerr
/// backend search, auto-fired on empty library or manually).
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

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
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Library'),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search',
              onPressed: _enterSearch,
            ),
          ],
          bottom: const TabBar(
            tabs: <Tab>[
              Tab(text: 'Artists'),
              Tab(text: 'Albums'),
              Tab(text: 'Playlists'),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[
            _ArtistsTab(),
            _AlbumsTab(),
            _PlaylistsTab(),
          ],
        ),
      ),
    );
  }
}
