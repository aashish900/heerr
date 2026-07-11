part of 'library_screen.dart';

// ---------------------------------------------------------------------------
// Browse mode (idle Library tab — unchanged from I1)
// ---------------------------------------------------------------------------

class _ArtistsTab extends ConsumerStatefulWidget {
  const _ArtistsTab();

  @override
  ConsumerState<_ArtistsTab> createState() => _ArtistsTabState();
}

class _ArtistsTabState extends ConsumerState<_ArtistsTab> {
  static const double _kRowExtent = 72;
  static const double _kChipRowExtent = 56;

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrubTo(String letter, List<Artist> artists) {
    final int? index = scrubTargetIndex(
      artists.map((Artist a) => a.name).toList(),
      letter,
    );
    if (index == null || !_scrollController.hasClients) return;
    final double target = _kChipRowExtent + index * _kRowExtent;
    _scrollController.jumpTo(
      target.clamp(0, _scrollController.position.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Artist>> async =
        ref.watch(sortedLibraryArtistsProvider);
    return async.when(
      loading: () => const SkeletonList(count: 6),
      error: (Object e, _) => Center(
        child: Text(e is ApiError ? e.message : 'Error: $e'),
      ),
      data: (List<Artist> artists) {
        final ArtistSort sort = ref.watch(artistSortNotifierProvider);
        final bool downloadedOnly = ref
            .watch(downloadedOnlyNotifierProvider(LibraryTab.artists));
        final Widget scrollView = CustomScrollView(
          controller: _scrollController,
          slivers: <Widget>[
            const SliverToBoxAdapter(
              child: SizedBox(
                height: _kChipRowExtent,
                child: LibraryFilterChips(tab: LibraryTab.artists),
              ),
            ),
            if (artists.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: downloadedOnly
                    ? const EmptyState(
                        icon: Icons.download_done_outlined,
                        title: 'No downloaded artists',
                        subtitle:
                            'Mark an album or artist for offline to see it '
                            'here.',
                      )
                    : const EmptyState(
                        icon: Icons.person_outline,
                        title: 'No artists yet',
                        subtitle:
                            'Library is empty. Download something via the '
                            'queue or search.',
                      ),
              )
            else ...<Widget>[
              SliverFixedExtentList(
                itemExtent: _kRowExtent,
                delegate: SliverChildBuilderDelegate(
                  (BuildContext c, int i) {
                    final Artist a = artists[i];
                    return _ArtistRow(artist: a);
                  },
                  childCount: artists.length,
                ),
              ),
              const SliverToBoxAdapter(child: _MostPlayedArtistsRail()),
            ],
          ],
        );
        // Scrub math assumes ascending alphabetical order.
        if (sort != ArtistSort.aToZ || artists.isEmpty) return scrollView;
        return Stack(
          children: <Widget>[
            scrollView,
            Positioned(
              right: 0,
              top: _kChipRowExtent,
              bottom: 8,
              width: 22,
              child: AlphabetScrubber(
                onLetter: (String letter) => _scrubTo(letter, artists),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One Artists-tab row (X5): circular avatar, name, album count.
class _ArtistRow extends StatelessWidget {
  const _ArtistRow({required this.artist});

  final Artist artist;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipOval(
        child: LibraryCoverArt(
          coverArtId: artist.coverArt,
          size: 44,
          borderRadius: 22,
        ),
      ),
      title: Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: artist.albumCount == null
          ? null
          : Text('${artist.albumCount} albums'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(Routes.libraryArtist(artist.id)),
    );
  }
}

/// "Most Played Artists" horizontal rail below the artist list (X5).
/// Hidden while loading, on error, and when the server has no play history
/// yet — the rail is a bonus surface, never a blocker.
class _MostPlayedArtistsRail extends ConsumerWidget {
  const _MostPlayedArtistsRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<MostPlayedArtist> entries =
        ref.watch(mostPlayedArtistsProvider).valueOrNull ??
            const <MostPlayedArtist>[];
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionHeader(label: 'Most Played Artists'),
        SizedBox(
          height: 124,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (BuildContext c, int i) =>
                _MostPlayedArtistCard(entry: entries[i]),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _MostPlayedArtistCard extends ConsumerWidget {
  const _MostPlayedArtistCard({required this.entry});

  final MostPlayedArtist entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => context.push(Routes.libraryArtist(entry.artistId)),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 84,
        child: Column(
          children: <Widget>[
            Stack(
              children: <Widget>[
                ClipOval(
                  child: LibraryCoverArt(
                    coverArtId: entry.coverArt,
                    size: 76,
                    borderRadius: 38,
                  ),
                ),
                // Gradient play badge — plays the artist's most-played
                // album (the rail entry's source album).
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: InkWell(
                    key: Key('most-played-play-${entry.artistId}'),
                    customBorder: const CircleBorder(),
                    onTap: () => playAlbumFromSubsonic(
                        ref, context, entry.topAlbumId),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        gradient: heerrGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow,
                          size: 18, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumsTab extends ConsumerStatefulWidget {
  const _AlbumsTab();

  @override
  ConsumerState<_AlbumsTab> createState() => _AlbumsTabState();
}

class _AlbumsTabState extends ConsumerState<_AlbumsTab> {
  /// How many albums the top grid shows (3 columns × 3 rows, mockup). The
  /// "Albums ›" list below always carries the full library.
  static const int _kGridCap = 9;

  // Fixed extents so the X4 scrubber can compute jump offsets exactly:
  // list rows use SliverFixedExtentList, the chip row + section header are
  // pinned to these heights via SizedBox.
  static const double _kRowExtent = 72;
  static const double _kChipRowExtent = 56;
  static const double _kHeaderExtent = 44;

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _rowSubtitle(Album a) {
    return <String?>[
      a.artist,
      a.year?.toString(),
      if (a.songCount != null) '${a.songCount} songs',
    ].whereType<String>().join(' • ');
  }

  /// Height of the grid block (padding included) for the given tab width —
  /// mirrors the SliverGrid geometry below so scrub jumps land on rows.
  double _gridExtent(double width, int albumCount) {
    final int shown = albumCount > _kGridCap ? _kGridCap : albumCount;
    final int rows = (shown + 2) ~/ 3;
    if (rows == 0) return 0;
    final double cellWidth = (width - 32 - 24) / 3;
    final double cellHeight = cellWidth / 0.64;
    return rows * cellHeight + (rows - 1) * 12 + 8;
  }

  void _scrubTo(String letter, List<Album> albums, double width) {
    final int? index = scrubTargetIndex(
      albums.map((Album a) => a.name).toList(),
      letter,
    );
    if (index == null || !_scrollController.hasClients) return;
    final double target = _kChipRowExtent +
        _gridExtent(width, albums.length) +
        _kHeaderExtent +
        index * _kRowExtent;
    _scrollController.jumpTo(
      target.clamp(0, _scrollController.position.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Album>> async =
        ref.watch(sortedLibraryAlbumsProvider);
    return async.when(
      loading: () => const SkeletonList(count: 6),
      error: (Object e, _) => Center(
        child: Text(e is ApiError ? e.message : 'Error: $e'),
      ),
      data: (List<Album> albums) {
        final AlbumSort sort = ref.watch(albumSortNotifierProvider);
        final bool downloadedOnly = ref
            .watch(downloadedOnlyNotifierProvider(LibraryTab.albums));
        final Set<String> markedAlbums = ref
                .watch(offlineManifestProvider)
                .valueOrNull
                ?.markedAlbums ??
            const <String>{};
        return LayoutBuilder(
          builder: (BuildContext c, BoxConstraints constraints) {
            final Widget scrollView = CustomScrollView(
              controller: _scrollController,
              slivers: <Widget>[
                const SliverToBoxAdapter(
                  child: SizedBox(
                    height: _kChipRowExtent,
                    child: LibraryFilterChips(tab: LibraryTab.albums),
                  ),
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
                                'Library is empty. Download something via '
                                'the queue or search.',
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
                        childCount: albums.length > _kGridCap
                            ? _kGridCap
                            : albums.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(
                      height: _kHeaderExtent,
                      child: _ListSectionHeader(label: 'Albums'),
                    ),
                  ),
                  SliverFixedExtentList(
                    itemExtent: _kRowExtent,
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
                          onTap: () =>
                              context.push(Routes.libraryAlbum(a.id)),
                        );
                      },
                      childCount: albums.length,
                    ),
                  ),
                ],
              ],
            );
            // The A–Z scrubber only makes sense over an alphabetical list.
            if (sort != AlbumSort.alphabetical || albums.isEmpty) {
              return scrollView;
            }
            return Stack(
              children: <Widget>[
                scrollView,
                Positioned(
                  right: 0,
                  top: _kChipRowExtent,
                  bottom: 8,
                  width: 22,
                  child: AlphabetScrubber(
                    onLetter: (String letter) =>
                        _scrubTo(letter, albums, constraints.maxWidth),
                  ),
                ),
              ],
            );
          },
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

  /// How many playlist cards the 2-column grid shows between the Favorites
  /// and Create cards (mockup: 3 rows of cards total).
  static const int _kGridCap = 6;

  String? _rowSubtitle(Playlist p) {
    final String joined = <String?>[
      if (p.owner != null) 'by ${p.owner}',
      if (p.songCount != null) '${p.songCount} songs',
    ].whereType<String>().join(' • ');
    return joined.isEmpty ? null : joined;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Playlist>> async =
        ref.watch(sortedLibraryPlaylistsProvider);
    return async.when(
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
        final int? favoritesCount =
            ref.watch(starredSongsProvider).valueOrNull?.length;
        final int cardCount = playlists.length > _kGridCap
            ? _kGridCap
            : playlists.length;
        return CustomScrollView(
          slivers: <Widget>[
            const SliverToBoxAdapter(
              child: SizedBox(
                height: 56,
                child: LibraryFilterChips(tab: LibraryTab.playlists),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.05,
                ),
                delegate: SliverChildBuilderDelegate(
                  (BuildContext c, int i) {
                    // Cell order: Favorites, playlist cards, Create.
                    if (i == 0) {
                      return FavoritesGridCard(
                        songCount: favoritesCount,
                        onTap: () =>
                            context.push(Routes.libraryFavorites),
                      );
                    }
                    if (i == cardCount + 1) {
                      return CreatePlaylistGridCard(
                        onTap: () =>
                            unawaited(_onCreatePressed(context, ref)),
                      );
                    }
                    final Playlist p = playlists[i - 1];
                    return PlaylistGridCard(
                      playlist: p,
                      onTap: () =>
                          context.push(Routes.libraryPlaylist(p.id)),
                    );
                  },
                  childCount: cardCount + 2,
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: _ListSectionHeader(label: 'Playlists'),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext c, int i) {
                  // Row order: Favorites, playlists, trailing For You.
                  if (i == 0) {
                    return ListTile(
                      key: const Key('library-favorites-row'),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: heerrGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.favorite,
                            color: Colors.black54),
                      ),
                      title: const Text('Favorites'),
                      subtitle: favoritesCount == null
                          ? null
                          : Text('$favoritesCount songs'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(Routes.libraryFavorites),
                    );
                  }
                  if (i == playlists.length + 1) {
                    return ListTile(
                      key: const Key('library-for-you-entry'),
                      leading: const Icon(Icons.recommend_outlined),
                      title: const Text('For You'),
                      subtitle:
                          const Text('Recommendations from your listening'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          context.push(Routes.libraryRecommendations),
                    );
                  }
                  final Playlist p = playlists[i - 1];
                  return LibraryResultTile(
                    title: p.name,
                    subtitle: _rowSubtitle(p),
                    coverArtId: p.coverArt,
                    trailingPlay: true,
                    isMarkedForOffline: markedPlaylists.contains(p.id),
                    onPlay: () =>
                        playPlaylistFromSubsonic(ref, context, p.id),
                    onTap: () => context.push(Routes.libraryPlaylist(p.id)),
                  );
                },
                childCount: playlists.length + 2,
              ),
            ),
          ],
        );
      },
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
