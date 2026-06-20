part of 'library_screen.dart';

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
                      findSimilarSeed: seedForSong(s),
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
