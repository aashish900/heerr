import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../models/download_response.dart';
import '../models/enums.dart';
import '../models/search_response.dart';
import '../models/search_result_item.dart';
import '../providers/download.dart';
import '../providers/search.dart';
import '../widgets/result_tile.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // Seed the text field from the provider so the user's last query
    // survives a tab-switch (Search → Queue → Search).
    _controller = TextEditingController(
      text: ref.read(searchQueryProvider).query,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SearchQueryState query = ref.watch(searchQueryProvider);
    final AsyncValue<SearchResponse> resultsAsync =
        ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _controller,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Search Spotify',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: ref.read(searchQueryProvider.notifier).setQuery,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<SpotifyType>(
              segments: const <ButtonSegment<SpotifyType>>[
                ButtonSegment<SpotifyType>(
                  value: SpotifyType.track,
                  label: Text('Tracks'),
                ),
                ButtonSegment<SpotifyType>(
                  value: SpotifyType.album,
                  label: Text('Albums'),
                ),
                ButtonSegment<SpotifyType>(
                  value: SpotifyType.playlist,
                  label: Text('Playlists'),
                ),
              ],
              selected: <SpotifyType>{query.type},
              onSelectionChanged: (Set<SpotifyType> set) {
                ref.read(searchQueryProvider.notifier).setType(set.first);
              },
            ),
          ),
          Expanded(
            child: _Body(query: query, resultsAsync: resultsAsync),
          ),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.query, required this.resultsAsync});

  final SearchQueryState query;
  final AsyncValue<SearchResponse> resultsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, _) => _Centered(text: _errorMessage(e)),
      data: (SearchResponse r) {
        if (query.query.trim().isEmpty) {
          return const _Centered(text: 'Type to search Spotify');
        }
        if (r.results.isEmpty) {
          return const _Centered(text: 'No results');
        }
        return ListView.builder(
          itemCount: r.results.length,
          itemBuilder: (BuildContext _, int i) {
            final SearchResultItem item = r.results[i];
            return ResultTile(
              item: item,
              onTap: () => _dispatchDownload(context, ref, item),
            );
          },
        );
      },
    );
  }
}

Future<void> _dispatchDownload(
  BuildContext context,
  WidgetRef ref,
  SearchResultItem item,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  try {
    final DownloadResponse res = await ref
        .read(downloadDispatcherProvider.notifier)
        .dispatch(item.spotifyUri);
    if (!context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(res.deduped ? 'Already downloaded' : 'Queued'),
        ),
      );
  } on ApiError catch (e) {
    if (!context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(e.message)));
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

String _errorMessage(Object e) {
  if (e is ApiError) return e.message;
  return 'Error: $e';
}
