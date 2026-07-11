import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/library/library_filters.dart';
import '../theme.dart';

/// Chip row under the Library segmented tabs (X2, LIBRARYSCREEN.md §4):
/// a sort chip (opens a bottom sheet of the tab's sort options), a
/// "Downloaded" toggle chip, and a trailing filter icon (decorative-only —
/// no further filters exist yet; see DEBT.md).
class LibraryFilterChips extends ConsumerWidget {
  const LibraryFilterChips({required this.tab, super.key});

  final LibraryTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
      child: Row(
        children: <Widget>[
          _SortChip(tab: tab),
          const SizedBox(width: 8),
          _DownloadedChip(tab: tab),
          const Spacer(),
          const IconButton(
            key: Key('library-filter-icon'),
            icon: Icon(Icons.filter_list),
            tooltip: 'More filters coming soon',
            onPressed: null,
          ),
        ],
      ),
    );
  }
}

/// The magenta sort chip. Label mirrors the tab's current sort; tapping
/// opens a bottom sheet listing that tab's sort options.
class _SortChip extends ConsumerWidget {
  const _SortChip({required this.tab});

  final LibraryTab tab;

  String _currentLabel(WidgetRef ref) => switch (tab) {
        LibraryTab.albums => ref.watch(albumSortNotifierProvider).label,
        LibraryTab.artists => ref.watch(artistSortNotifierProvider).label,
        LibraryTab.playlists =>
          ref.watch(playlistSortNotifierProvider).label,
      };

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    switch (tab) {
      case LibraryTab.albums:
        final AlbumSort? picked = await _showSortSheet<AlbumSort>(
          context,
          AlbumSort.values,
          ref.read(albumSortNotifierProvider),
          (AlbumSort s) => s.label,
        );
        if (picked != null) {
          ref.read(albumSortNotifierProvider.notifier).set(picked);
        }
      case LibraryTab.artists:
        final ArtistSort? picked = await _showSortSheet<ArtistSort>(
          context,
          ArtistSort.values,
          ref.read(artistSortNotifierProvider),
          (ArtistSort s) => s.label,
        );
        if (picked != null) {
          ref.read(artistSortNotifierProvider.notifier).set(picked);
        }
      case LibraryTab.playlists:
        final PlaylistSort? picked = await _showSortSheet<PlaylistSort>(
          context,
          PlaylistSort.values,
          ref.read(playlistSortNotifierProvider),
          (PlaylistSort s) => s.label,
        );
        if (picked != null) {
          ref.read(playlistSortNotifierProvider.notifier).set(picked);
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      key: const Key('library-sort-chip'),
      color: heerrMagenta.withValues(alpha: 0.22),
      shape: StadiumBorder(
        side: BorderSide(color: heerrMagenta.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _pick(context, ref),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 7, 8, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _currentLabel(ref),
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: heerrMagenta),
              ),
              const Icon(Icons.arrow_drop_down,
                  size: 20, color: heerrMagenta),
            ],
          ),
        ),
      ),
    );
  }
}

Future<T?> _showSortSheet<T>(
  BuildContext context,
  List<T> options,
  T current,
  String Function(T) label,
) {
  return showModalBottomSheet<T>(
    context: context,
    builder: (BuildContext ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Sort by',
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
          ),
          for (final T option in options)
            ListTile(
              title: Text(label(option)),
              trailing: option == current
                  ? const Icon(Icons.check, color: heerrMagenta)
                  : null,
              onTap: () => Navigator.of(ctx).pop(option),
            ),
        ],
      ),
    ),
  );
}

class _DownloadedChip extends ConsumerWidget {
  const _DownloadedChip({required this.tab});

  final LibraryTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool selected = ref.watch(downloadedOnlyNotifierProvider(tab));
    return FilterChip(
      key: const Key('library-downloaded-chip'),
      label: const Text('Downloaded'),
      selected: selected,
      showCheckmark: false,
      selectedColor: heerrMagenta.withValues(alpha: 0.22),
      side: selected
          ? BorderSide(color: heerrMagenta.withValues(alpha: 0.6))
          : null,
      labelStyle: selected ? const TextStyle(color: heerrMagenta) : null,
      onSelected: (_) =>
          ref.read(downloadedOnlyNotifierProvider(tab).notifier).toggle(),
    );
  }
}
