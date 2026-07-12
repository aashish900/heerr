import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/downloads_filters.dart';
import '../../theme.dart';

/// Chip row under the Downloads segmented tabs (DL5, DOWNLOADSSCREEN.md §4):
/// a sort chip on every tab, plus "Lossless" and "Today" toggles on the
/// Songs tab only, and a trailing decorative filter icon (same convention as
/// `LibraryFilterChips` — no further filters exist yet).
class DownloadsFilterChips extends ConsumerWidget {
  const DownloadsFilterChips({required this.tab, super.key});

  final DownloadsTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            _SortChip(tab: tab),
            if (tab == DownloadsTab.songs) ...<Widget>[
              const SizedBox(width: 8),
              const _LosslessChip(),
              const SizedBox(width: 8),
              const _TodayChip(),
            ],
            const SizedBox(width: 8),
            const IconButton(
              key: Key('downloads-filter-icon'),
              icon: Icon(Icons.filter_list),
              tooltip: 'More filters coming soon',
              onPressed: null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SortChip extends ConsumerWidget {
  const _SortChip({required this.tab});

  final DownloadsTab tab;

  String _currentLabel(WidgetRef ref) => switch (tab) {
        DownloadsTab.songs => ref.watch(downloadsSongSortNotifierProvider).label,
        DownloadsTab.albums => ref.watch(downloadsAlbumSortNotifierProvider).label,
        DownloadsTab.playlists =>
          ref.watch(downloadsPlaylistSortNotifierProvider).label,
      };

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    switch (tab) {
      case DownloadsTab.songs:
        final DownloadsSongSort? picked = await _showSortSheet<DownloadsSongSort>(
          context,
          DownloadsSongSort.values,
          ref.read(downloadsSongSortNotifierProvider),
          (DownloadsSongSort s) => s.label,
        );
        if (picked != null) {
          ref.read(downloadsSongSortNotifierProvider.notifier).set(picked);
        }
      case DownloadsTab.albums:
        final DownloadsContainerSort? picked =
            await _showSortSheet<DownloadsContainerSort>(
          context,
          DownloadsContainerSort.values,
          ref.read(downloadsAlbumSortNotifierProvider),
          (DownloadsContainerSort s) => s.label,
        );
        if (picked != null) {
          ref.read(downloadsAlbumSortNotifierProvider.notifier).set(picked);
        }
      case DownloadsTab.playlists:
        final DownloadsContainerSort? picked =
            await _showSortSheet<DownloadsContainerSort>(
          context,
          DownloadsContainerSort.values,
          ref.read(downloadsPlaylistSortNotifierProvider),
          (DownloadsContainerSort s) => s.label,
        );
        if (picked != null) {
          ref.read(downloadsPlaylistSortNotifierProvider.notifier).set(picked);
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      key: const Key('downloads-sort-chip'),
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
              const Icon(Icons.arrow_drop_down, size: 20, color: heerrMagenta),
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
              child: Text('Sort by', style: Theme.of(ctx).textTheme.titleMedium),
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

class _LosslessChip extends ConsumerWidget {
  const _LosslessChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool selected = ref.watch(downloadsLosslessOnlyNotifierProvider);
    return FilterChip(
      key: const Key('downloads-lossless-chip'),
      label: const Text('Lossless'),
      selected: selected,
      showCheckmark: false,
      selectedColor: heerrMagenta.withValues(alpha: 0.22),
      side: selected ? BorderSide(color: heerrMagenta.withValues(alpha: 0.6)) : null,
      labelStyle: selected ? const TextStyle(color: heerrMagenta) : null,
      onSelected: (_) =>
          ref.read(downloadsLosslessOnlyNotifierProvider.notifier).toggle(),
    );
  }
}

class _TodayChip extends ConsumerWidget {
  const _TodayChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool selected = ref.watch(downloadsTodayOnlyNotifierProvider);
    return FilterChip(
      key: const Key('downloads-today-chip'),
      label: const Text('Downloaded Today'),
      selected: selected,
      showCheckmark: false,
      selectedColor: heerrMagenta.withValues(alpha: 0.22),
      side: selected ? BorderSide(color: heerrMagenta.withValues(alpha: 0.6)) : null,
      labelStyle: selected ? const TextStyle(color: heerrMagenta) : null,
      onSelected: (_) =>
          ref.read(downloadsTodayOnlyNotifierProvider.notifier).toggle(),
    );
  }
}
