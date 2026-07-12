import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/offline/offline_manifest.dart';
import 'package:heerr/providers/downloaded_songs.dart';
import 'package:heerr/providers/downloads_filters.dart';
import 'package:heerr/providers/downloads_views.dart';

// DL6: the Songs-tab join provider (Song + manifest entry) and the pure
// sort helper. D7: "Lossless" matches a suffix set, not just flac.

const Song _a = Song(id: 'a', title: 'Alpha', artist: 'X');
const Song _b = Song(id: 'b', title: 'Bravo', artist: 'X');
const Song _c = Song(id: 'c', title: 'Charlie', artist: 'X');

OfflineManifest _manifestWith(Map<String, OfflineSongEntry> entries) =>
    OfflineManifest(songs: entries);

void main() {
  group('downloadedSongsViewProvider', () {
    test('joins songs with their manifest entry, dropping unmatched ids',
        () async {
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          downloadedSongsProvider.overrideWith((_) async => <Song>[_a, _b]),
          offlineManifestProvider.overrideWith(
            (_) async => _manifestWith(<String, OfflineSongEntry>{
              'a': const OfflineSongEntry(state: OfflineSongState.ready, size: 100),
              // 'b' has no manifest entry — should be dropped, not crash.
            }),
          ),
        ],
      );
      addTearDown(c.dispose);

      final List<DownloadedSongRow> rows =
          await c.read(downloadedSongsViewProvider.future);

      expect(rows.length, 1);
      expect(rows.single.song.id, 'a');
      expect(rows.single.entry.size, 100);
    });

    test('Lossless filter matches flac/alac/wav, not mp3', () async {
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          downloadedSongsProvider.overrideWith((_) async => <Song>[_a, _b, _c]),
          offlineManifestProvider.overrideWith(
            (_) async => _manifestWith(<String, OfflineSongEntry>{
              'a': const OfflineSongEntry(state: OfflineSongState.ready, suffix: 'flac'),
              'b': const OfflineSongEntry(state: OfflineSongState.ready, suffix: 'mp3'),
              'c': const OfflineSongEntry(state: OfflineSongState.ready, suffix: 'alac'),
            }),
          ),
          downloadsLosslessOnlyNotifierProvider.overrideWith(() {
            final _ToggledLossless n = _ToggledLossless();
            return n;
          }),
        ],
      );
      addTearDown(c.dispose);

      final List<DownloadedSongRow> rows =
          await c.read(downloadedSongsViewProvider.future);

      expect(rows.map((DownloadedSongRow r) => r.song.id), <String>['a', 'c']);
    });

    test('Today filter keeps only entries downloaded on the current day',
        () async {
      final DateTime now = DateTime.now();
      final DateTime yesterday = now.subtract(const Duration(days: 1));
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          downloadedSongsProvider.overrideWith((_) async => <Song>[_a, _b]),
          offlineManifestProvider.overrideWith(
            (_) async => _manifestWith(<String, OfflineSongEntry>{
              'a': OfflineSongEntry(state: OfflineSongState.ready, downloadedAt: now),
              'b': OfflineSongEntry(state: OfflineSongState.ready, downloadedAt: yesterday),
            }),
          ),
          downloadsTodayOnlyNotifierProvider.overrideWith(() => _ToggledToday()),
        ],
      );
      addTearDown(c.dispose);

      final List<DownloadedSongRow> rows =
          await c.read(downloadedSongsViewProvider.future);

      expect(rows.map((DownloadedSongRow r) => r.song.id), <String>['a']);
    });
  });

  group('sortDownloadedSongRows', () {
    DownloadedSongRow row(Song s, {DateTime? at, int? size}) =>
        (song: s, entry: OfflineSongEntry(state: OfflineSongState.ready, downloadedAt: at, size: size));

    test('aToZ sorts by title case-insensitively', () {
      final List<DownloadedSongRow> out = sortDownloadedSongRows(
        <DownloadedSongRow>[row(_c), row(_a), row(_b)],
        DownloadsSongSort.aToZ,
      );
      expect(out.map((DownloadedSongRow r) => r.song.id), <String>['a', 'b', 'c']);
    });

    test('recent sorts newest downloadedAt first, nulls last', () {
      final DateTime t1 = DateTime(2026, 1, 1);
      final DateTime t2 = DateTime(2026, 6, 1);
      final List<DownloadedSongRow> out = sortDownloadedSongRows(
        <DownloadedSongRow>[row(_a, at: t1), row(_b, at: t2), row(_c)],
        DownloadsSongSort.recent,
      );
      expect(out.map((DownloadedSongRow r) => r.song.id), <String>['b', 'a', 'c']);
    });

    test('largest sorts by size descending, missing size treated as 0', () {
      final List<DownloadedSongRow> out = sortDownloadedSongRows(
        <DownloadedSongRow>[row(_a, size: 10), row(_b, size: 100), row(_c)],
        DownloadsSongSort.largest,
      );
      expect(out.map((DownloadedSongRow r) => r.song.id), <String>['b', 'a', 'c']);
    });
  });
}

class _ToggledLossless extends DownloadsLosslessOnlyNotifier {
  @override
  bool build() => true;
}

class _ToggledToday extends DownloadsTodayOnlyNotifier {
  @override
  bool build() => true;
}
