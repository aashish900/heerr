import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_error.dart';
import '../../models/search_response.dart';
import '../../models/search_result_item.dart';
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
import '../../providers/library/combined_search.dart';
import '../../providers/library/library_albums.dart';
import '../../providers/library/library_artists.dart';
import '../../providers/library/library_playlists.dart';
import '../../providers/library/library_search_query.dart';
import '../../providers/library/playlist_mutations.dart';
import '../../router.dart';
import '../../widgets/add_to_playlist_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_snackbar.dart';
import '../../widgets/library_result_tile.dart';
import '../../widgets/playlist_dialogs.dart';
import '../../widgets/result_tile.dart';
import '../../widgets/skeleton.dart';

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
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    final String initial = ref.read(librarySearchQueryProvider);
    _searchController = TextEditingController(text: initial);
    _searching = initial.isNotEmpty;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _enterSearch() {
    setState(() => _searching = true);
  }

  void _exitSearch() {
    _searchController.clear();
    ref.read(librarySearchQueryProvider.notifier).clear();
    setState(() => _searching = false);
  }

  void _onQueryChanged(String value) {
    ref.read(librarySearchQueryProvider.notifier).set(value);
  }

  @override
  Widget build(BuildContext context) {
    if (_searching) {
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

// ---------------------------------------------------------------------------
// Search mode
// ---------------------------------------------------------------------------

class _SearchModeScaffold extends ConsumerWidget {
  const _SearchModeScaffold({
    required this.controller,
    required this.onQueryChanged,
    required this.onExit,
  });

  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String query = ref.watch(librarySearchQueryProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Close search',
          onPressed: onExit,
        ),
        title: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search library + YouTube Music',
            border: InputBorder.none,
          ),
          onChanged: onQueryChanged,
        ),
        actions: <Widget>[
          if (controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Clear',
              onPressed: () {
                controller.clear();
                onQueryChanged('');
              },
            ),
        ],
      ),
      body: query.trim().isEmpty
          ? const EmptyState(
              icon: Icons.search,
              title: 'Search your library',
              subtitle:
                  'We check Navidrome first. YouTube Music kicks in if nothing matches.',
            )
          : _CombinedResultsBody(query: query),
    );
  }
}

class _CombinedResultsBody extends ConsumerWidget {
  const _CombinedResultsBody({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CombinedSearchResult result =
        ref.watch(combinedSearchProvider(query));

    final AsyncValue<SearchResult3> library = result.library;
    final AsyncValue<SearchResponse>? ytm = result.ytm;
    final bool manuallyTriggered = ref.watch(
      ytmManualTriggerProvider
          .select((Set<String> s) => s.contains(query)),
    );

    // K-polish: heerrGreen indicator for the song row whose subsonicId
    // matches the active MediaItem. Null when nothing is playing.
    final String? currentSubsonicId = ref
        .watch(currentMediaItemProvider)
        .valueOrNull
        ?.extras?['subsonicId'] as String?;

    return library.when(
      loading: () => const SkeletonList(count: 6),
      error: (Object e, _) => _ErrorView(error: e),
      data: (SearchResult3 lib) {
        final bool libEmpty =
            lib.artist.isEmpty && lib.album.isEmpty && lib.song.isEmpty;
        final bool bothEmpty = libEmpty &&
            (ytm?.maybeWhen(
                  data: (SearchResponse r) => r.results.isEmpty,
                  orElse: () => false,
                ) ??
                false);

        if (bothEmpty) {
          return const EmptyState(
            icon: Icons.search_off,
            title: 'No matches',
            subtitle:
                'Nothing in your library or on YouTube Music for that query.',
          );
        }

        return ListView(
          children: <Widget>[
            // -------------------- Library section --------------------
            const _SectionHeader(label: 'In your library'),
            if (libEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Text('Not in your library.'),
              )
            else ...<Widget>[
              if (lib.song.isNotEmpty) ...<Widget>[
                const _SubSectionHeader(label: 'Songs'),
                for (final Song s in lib.song)
                  LibraryResultTile(
                    title: s.title,
                    subtitle: _songSubtitle(s),
                    coverArtId: s.coverArt,
                    isCurrentlyPlaying: s.id == currentSubsonicId,
                    onTap: () => playSongFromSubsonic(ref, context, s),
                    onLongPress: () => AddToPlaylistSheet.show(
                      context: context,
                      songIds: <String>[s.id],
                    ),
                  ),
              ],
              if (lib.album.isNotEmpty) ...<Widget>[
                const _SubSectionHeader(label: 'Albums'),
                for (final Album a in lib.album)
                  LibraryResultTile(
                    title: a.name,
                    subtitle: a.artist,
                    coverArtId: a.coverArt,
                    trailingPlay: true,
                    isMarkedForOffline: ref
                            .watch(offlineManifestProvider)
                            .valueOrNull
                            ?.markedAlbums
                            .contains(a.id) ??
                        false,
                    onPlay: () =>
                        playAlbumFromSubsonic(ref, context, a.id),
                    onTap: () => context.push(Routes.libraryAlbum(a.id)),
                  ),
              ],
              if (lib.artist.isNotEmpty) ...<Widget>[
                const _SubSectionHeader(label: 'Artists'),
                for (final Artist a in lib.artist)
                  LibraryResultTile(
                    title: a.name,
                    subtitle: a.albumCount == null
                        ? null
                        : '${a.albumCount} albums',
                    coverArtId: a.coverArt,
                    onTap: () => context.push(Routes.libraryArtist(a.id)),
                  ),
              ],
            ],

            // -------------------- YouTube Music section --------------------
            const _SectionHeader(label: 'On YouTube Music'),
            if (ytm == null && !libEmpty && !manuallyTriggered)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: FilledButton.tonal(
                  onPressed: () => ref
                      .read(ytmManualTriggerProvider.notifier)
                      .trigger(query),
                  child: const Text('Search more on YouTube Music'),
                ),
              )
            else if (ytm != null)
              _YtmSection(ytm: ytm)
            else
              // libEmpty=false, manuallyTriggered=false, ytm=null —
              // this branch shouldn't be reachable; render nothing.
              const SizedBox.shrink(),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  String? _songSubtitle(Song s) {
    final String? artist = s.artist;
    final String? album = s.album;
    if (artist != null && album != null) return '$artist • $album';
    return artist ?? album;
  }
}

class _YtmSection extends ConsumerWidget {
  const _YtmSection({required this.ytm});

  final AsyncValue<SearchResponse> ytm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ytm.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object e, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Text(
          e is ApiError ? e.message : 'YouTube Music search failed: $e',
        ),
      ),
      data: (SearchResponse r) {
        if (r.results.isEmpty) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Text('Nothing on YouTube Music either.'),
          );
        }
        return Column(
          children: <Widget>[
            for (final SearchResultItem item in r.results)
              ResultTile(
                item: item,
                onTap: () async {
                  try {
                    await ref
                        .read(downloadDispatcherProvider.notifier)
                        .dispatch(
                          item.sourceUrl,
                          sourceType: item.sourceType,
                          displayName: item.title,
                        );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: kSnackBarDuration,
                        content: Text('Queued: ${item.title}'),
                      ),
                    );
                  } on ApiError catch (e) {
                    if (!context.mounted) return;
                    showApiError(context, e, action: 'download');
                  }
                },
              ),
          ],
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(error is ApiError ? (error as ApiError).message : 'Error: $error'),
    );
  }
}

// ---------------------------------------------------------------------------
// Browse mode (idle Library tab — unchanged from I1)
// ---------------------------------------------------------------------------

class _ArtistsTab extends ConsumerWidget {
  const _ArtistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ArtistIndex>> async =
        ref.watch(libraryArtistsProvider);
    return async.when(
      loading: () => const SkeletonList(count: 6),
      error: (Object e, _) => Center(
        child: Text(e is ApiError ? e.message : 'Error: $e'),
      ),
      data: (List<ArtistIndex> indices) {
        if (indices.isEmpty ||
            indices.every((ArtistIndex i) => i.artist.isEmpty)) {
          return const EmptyState(
            icon: Icons.person_outline,
            title: 'No artists yet',
            subtitle:
                'Library is empty. Download something via the queue or search.',
          );
        }
        return ListView(
          children: <Widget>[
            for (final ArtistIndex group in indices) ...<Widget>[
              if (group.artist.isNotEmpty) _SectionHeader(label: group.name),
              for (final Artist a in group.artist)
                LibraryResultTile(
                  title: a.name,
                  subtitle: a.albumCount == null
                      ? null
                      : '${a.albumCount} albums',
                  coverArtId: a.coverArt,
                  onTap: () => context.push(Routes.libraryArtist(a.id)),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _AlbumsTab extends ConsumerWidget {
  const _AlbumsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Album>> async = ref.watch(libraryAlbumsProvider);
    return async.when(
      loading: () => const SkeletonList(count: 6),
      error: (Object e, _) => Center(
        child: Text(e is ApiError ? e.message : 'Error: $e'),
      ),
      data: (List<Album> albums) {
        if (albums.isEmpty) {
          return const EmptyState(
            icon: Icons.album_outlined,
            title: 'No albums yet',
            subtitle:
                'Library is empty. Download something via the queue or search.',
          );
        }
        final Set<String> markedAlbums = ref
                .watch(offlineManifestProvider)
                .valueOrNull
                ?.markedAlbums ??
            const <String>{};
        return ListView.builder(
          itemCount: albums.length,
          itemBuilder: (BuildContext c, int i) {
            final Album a = albums[i];
            return LibraryResultTile(
              title: a.name,
              subtitle: a.artist,
              coverArtId: a.coverArt,
              trailingPlay: true,
              isMarkedForOffline: markedAlbums.contains(a.id),
              onPlay: () => playAlbumFromSubsonic(ref, context, a.id),
              onTap: () => context.push(Routes.libraryAlbum(a.id)),
            );
          },
        );
      },
    );
  }
}

class _PlaylistsTab extends ConsumerWidget {
  const _PlaylistsTab();

  Future<void> _onCreatePressed(BuildContext context, WidgetRef ref) async {
    final String? name = await CreatePlaylistDialog.show(context);
    if (name == null || !context.mounted) return;
    try {
      final Playlist created = await ref
          .read(playlistMutationsProvider.notifier)
          .createPlaylist(name: name);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: kSnackBarDuration,
          content: Text('Playlist "${created.name}" created'),
        ),
      );
      // GoRouter.maybeOf so widget tests without a router ancestor don't
      // crash on the post-create navigation hop (same fail-soft pattern as
      // showApiError's 401 redirect).
      final GoRouter? router = GoRouter.maybeOf(context);
      if (router != null) {
        unawaited(router.push<dynamic>(Routes.libraryPlaylist(created.id)));
      }
    } on ApiError catch (e) {
      if (!context.mounted) return;
      showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Playlist>> async =
        ref.watch(libraryPlaylistsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => unawaited(_onCreatePressed(context, ref)),
        icon: const Icon(Icons.add),
        label: const Text('New playlist'),
      ),
      body: async.when(
        loading: () => const SkeletonList(count: 6),
        error: (Object e, _) => Center(
          child: Text(e is ApiError ? e.message : 'Error: $e'),
        ),
        data: (List<Playlist> playlists) {
          final Set<String> markedPlaylists = ref
                  .watch(offlineManifestProvider)
                  .valueOrNull
                  ?.markedPlaylists ??
              const <String>{};
          // Total = N playlists + 1 trailing "For You →" entry point.
          return ListView.builder(
            itemCount: playlists.length + 1,
            itemBuilder: (BuildContext c, int i) {
              if (i == playlists.length) {
                return ListTile(
                  key: const Key('library-for-you-entry'),
                  leading: const Icon(Icons.recommend_outlined),
                  title: const Text('For You'),
                  subtitle: const Text('Recommendations from your listening'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.libraryRecommendations),
                );
              }
              final Playlist p = playlists[i];
              return LibraryResultTile(
                title: p.name,
                subtitle: p.songCount == null ? null : '${p.songCount} songs',
                coverArtId: p.coverArt,
                trailingPlay: true,
                isMarkedForOffline: markedPlaylists.contains(p.id),
                onPlay: () => playPlaylistFromSubsonic(ref, context, p.id),
                onTap: () => context.push(Routes.libraryPlaylist(p.id)),
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared little widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SubSectionHeader extends StatelessWidget {
  const _SubSectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
