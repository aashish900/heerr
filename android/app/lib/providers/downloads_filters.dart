import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'downloads_filters.g.dart';

/// Which Downloads tab a filter belongs to (DL5, DOWNLOADSSCREEN.md §4).
/// Matches the tab bar order fixed in DL1 (D3: Songs first).
enum DownloadsTab { songs, albums, playlists }

/// Sort orders for the Songs tab.
enum DownloadsSongSort { recent, largest, aToZ }

/// Sort orders for the Albums / Playlists tabs (no per-tab data reason to
/// diverge, so both share one enum).
enum DownloadsContainerSort { recent, alphabetical }

extension DownloadsSongSortLabel on DownloadsSongSort {
  String get label => switch (this) {
        DownloadsSongSort.recent => 'Recent',
        DownloadsSongSort.largest => 'Largest',
        DownloadsSongSort.aToZ => 'A–Z',
      };
}

extension DownloadsContainerSortLabel on DownloadsContainerSort {
  String get label => switch (this) {
        DownloadsContainerSort.recent => 'Recent',
        DownloadsContainerSort.alphabetical => 'A–Z',
      };
}

@riverpod
class DownloadsSongSortNotifier extends _$DownloadsSongSortNotifier {
  @override
  DownloadsSongSort build() => DownloadsSongSort.recent;

  void set(DownloadsSongSort value) => state = value;
}

@riverpod
class DownloadsAlbumSortNotifier extends _$DownloadsAlbumSortNotifier {
  @override
  DownloadsContainerSort build() => DownloadsContainerSort.recent;

  void set(DownloadsContainerSort value) => state = value;
}

@riverpod
class DownloadsPlaylistSortNotifier extends _$DownloadsPlaylistSortNotifier {
  @override
  DownloadsContainerSort build() => DownloadsContainerSort.recent;

  void set(DownloadsContainerSort value) => state = value;
}

/// "Lossless" toggle (Songs tab only). D7: matches a suffix set, not just
/// `flac` — the DL6 join provider owns that logic; this notifier only holds
/// the on/off state.
@riverpod
class DownloadsLosslessOnlyNotifier extends _$DownloadsLosslessOnlyNotifier {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

/// "Today" toggle (Songs tab only) — filters to songs whose
/// `OfflineSongEntry.downloadedAt` falls on the current calendar day.
@riverpod
class DownloadsTodayOnlyNotifier extends _$DownloadsTodayOnlyNotifier {
  @override
  bool build() => false;

  void toggle() => state = !state;
}
