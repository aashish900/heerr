part of 'library_screen.dart';

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

  /// How many albums the top grid shows (3 columns × 3 rows, mockup). The
  /// "Albums ›" list below always carries the full library.
  static const int _kGridCap = 9;

  String _rowSubtitle(Album a) {
    return <String?>[
      a.artist,
      a.year?.toString(),
      if (a.songCount != null) '${a.songCount} songs',
    ].whereType<String>().join(' • ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Album>> async =
        ref.watch(sortedLibraryAlbumsProvider);
    return async.when(
      loading: () => const SkeletonList(count: 6),
      error: (Object e, _) => Center(
        child: Text(e is ApiError ? e.message : 'Error: $e'),
      ),
      data: (List<Album> albums) {
        final bool downloadedOnly = ref
            .watch(downloadedOnlyNotifierProvider(LibraryTab.albums));
        final Set<String> markedAlbums = ref
                .watch(offlineManifestProvider)
                .valueOrNull
                ?.markedAlbums ??
            const <String>{};
        return CustomScrollView(
          slivers: <Widget>[
            const SliverToBoxAdapter(
              child: LibraryFilterChips(tab: LibraryTab.albums),
            ),
            if (albums.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: downloadedOnly
                    ? const EmptyState(
                        icon: Icons.download_done_outlined,
                        title: 'No downloaded albums',
                        subtitle:
                            'Mark an album for offline to see it here.',
                      )
                    : const EmptyState(
                        icon: Icons.album_outlined,
                        title: 'No albums yet',
                        subtitle:
                            'Library is empty. Download something via the '
                            'queue or search.',
                      ),
              )
            else ...<Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.64,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext c, int i) {
                      final Album a = albums[i];
                      return AlbumGridCard(
                        album: a,
                        downloaded: markedAlbums.contains(a.id),
                        onTap: () =>
                            context.push(Routes.libraryAlbum(a.id)),
                      );
                    },
                    childCount:
                        albums.length > _kGridCap ? _kGridCap : albums.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: _ListSectionHeader(label: 'Albums'),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext c, int i) {
                    final Album a = albums[i];
                    return LibraryResultTile(
                      title: a.name,
                      subtitle: _rowSubtitle(a),
                      coverArtId: a.coverArt,
                      trailingPlay: true,
                      isMarkedForOffline: markedAlbums.contains(a.id),
                      onPlay: () =>
                          playAlbumFromSubsonic(ref, context, a.id),
                      onTap: () => context.push(Routes.libraryAlbum(a.id)),
                    );
                  },
                  childCount: albums.length,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// "Albums ›" / "Playlists ›" style section header between the grid and the
/// full list (X3/X6).
class _ListSectionHeader extends StatelessWidget {
  const _ListSectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
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
      // Gradient CTA per the redesign: the FAB itself is transparent/flat and
      // the magenta→violet gradient comes from the wrapping box (FABs can't
      // take a gradient directly). Radius matches the M3 extended-FAB shape.
      floatingActionButton: DecoratedBox(
        decoration: BoxDecoration(
          gradient: heerrGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: FloatingActionButton.extended(
          onPressed: () => unawaited(_onCreatePressed(context, ref)),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black,
          elevation: 0,
          icon: const Icon(Icons.add),
          label: const Text('New playlist'),
        ),
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
