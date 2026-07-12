import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dio/dio.dart';

import '../api/api_error.dart';
import '../api/subsonic_client.dart';
import '../api/subsonic_endpoints.dart';
import '../models/job_view.dart';
import '../models/profile.dart';
import '../models/search_result_item.dart';
import '../models/subsonic/album.dart';
import '../models/subsonic/artist.dart';
import '../models/subsonic/playlist.dart';
import '../models/subsonic/search_result3.dart';
import '../models/subsonic/song.dart';
import '../offline/local_uri.dart';
import '../providers/library/library_album.dart';
import '../providers/library/library_artist.dart';
import '../providers/library/library_playlist.dart';
import '../providers/profiles/active_profile.dart';
import '../providers/server_creds.dart';
import '../widgets/error_snackbar.dart';
import 'heerr_audio_handler.dart';
import 'player_provider.dart';
import 'search_result_to_media_item.dart';
import 'song_to_media_item.dart';

/// Resolved Navidrome credentials. `null` means at least one of the three
/// required fields is missing — the caller surfaces a "creds missing" snackbar.
class _Creds {
  const _Creds(this.url, this.user, this.pass);
  final String url;
  final String user;
  final String pass;
}

Future<_Creds?> _resolveCreds(WidgetRef ref) async {
  final ServerCreds settings = ref.read(serverCredsProvider);
  final String? url = settings.navidromeBaseUrl;
  final String? user = settings.navidromeUsername;
  final String? pass = settings.navidromePassword;
  if (url == null || url.isEmpty ||
      user == null || user.isEmpty ||
      pass == null || pass.isEmpty) {
    return null;
  }
  return _Creds(url, user, pass);
}

void _credsMissingSnack(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    duration: kSnackBarDuration,
    content: Text(
      'Navidrome creds missing — fill them in under Settings → Servers',
    ),
  ));
}

void _errSnack(BuildContext context, Object e) {
  final String msg = e is ApiError ? e.message : 'Play failed: $e';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    duration: kSnackBarDuration,
    content: Text(msg),
  ));
}

Future<MediaItem> _toMediaItem(WidgetRef ref, Song s, _Creds c) async {
  // Single chokepoint: ask the offline layer if we have a local file for
  // this song id; pass it through to songToMediaItem so MediaItem.id becomes
  // file://… instead of the Subsonic stream URL. Null = stream.
  // Awaits the `.future` so the manifest provider has fully rebuilt after
  // a recent sync — without this, a fresh download would be invisible to
  // the player until the next time the manifest cache happens to refresh
  // (the "have to download twice to play offline" bug).
  final String? localUri =
      await ref.read(localUriForProvider(s.id).future);
  String? localPath;
  if (localUri != null) {
    final Uri parsed = Uri.parse(localUri);
    if (parsed.scheme == 'file') {
      localPath = parsed.toFilePath();
    }
  }
  return songToMediaItem(
    song: s,
    navidromeBaseUrl: c.url,
    navidromeUsername: c.user,
    navidromePassword: c.pass,
    localFilePath: localPath,
  );
}

/// Play a single Subsonic [Song]. Replaces the queue with just this song.
Future<void> playSongFromSubsonic(
  WidgetRef ref,
  BuildContext context,
  Song song,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  try {
    final _Creds? creds = await _resolveCreds(ref);
    if (creds == null) {
      if (context.mounted) _credsMissingSnack(context);
      return;
    }
    final MediaItem item = await _toMediaItem(ref, song, creds);
    await ref.read(audioHandlerProvider).playSong(item);
    messenger.showSnackBar(SnackBar(
      duration: kSnackBarDuration,
      content: Text('Playing: ${song.title}'),
    ));
  } catch (e) {
    if (context.mounted) _errSnack(context, e);
  }
}

/// Stream a not-in-library online search result through the backend
/// preview proxy (Phase K / Phase T), without downloading it first. Replaces
/// the queue with just this preview.
///
/// Deliberately bypasses [songToMediaItem] / [_toMediaItem] — there is no
/// Subsonic song id and no local file, so the MediaItem is built straight from
/// the search result with `id` = the `/preview/stream` URL (see
/// [searchResultToMediaItem]). Reads the heerr base URL + bearer token from the
/// active profile at the call site.
Future<void> playPreview(
  WidgetRef ref,
  BuildContext context,
  SearchResultItem item,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  try {
    final Profile? profile = ref.read(activeProfileProvider);
    if (profile == null ||
        profile.heerrBaseUrl.isEmpty ||
        profile.heerrBearerToken.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        duration: kSnackBarDuration,
        content: Text('Not signed in — sign in under Settings.'),
      ));
      return;
    }
    final MediaItem mediaItem = searchResultToMediaItem(
      item: item,
      heerrBaseUrl: profile.heerrBaseUrl,
      token: profile.heerrBearerToken,
    );
    await ref.read(audioHandlerProvider).playSong(mediaItem);
    messenger.showSnackBar(SnackBar(
      duration: kSnackBarDuration,
      content: Text('Preview: ${item.title}'),
    ));
  } catch (e) {
    if (context.mounted) _errSnack(context, e);
  }
}

/// #35: append [songs] to the end of the Now Playing queue without
/// interrupting the current track. When nothing is queued yet there is
/// nothing to append behind, so it behaves like "Play" (loads the songs
/// and starts playback) — matching what every mainstream player does for
/// add-to-queue-from-cold.
Future<void> addSongsToQueue(
  WidgetRef ref,
  BuildContext context,
  List<Song> songs,
) async {
  if (songs.isEmpty) return;
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  try {
    final _Creds? creds = await _resolveCreds(ref);
    if (creds == null) {
      if (context.mounted) _credsMissingSnack(context);
      return;
    }
    final List<MediaItem> items = await Future.wait<MediaItem>(
      songs.map((Song s) => _toMediaItem(ref, s, creds)),
    );
    final HeerrAudioHandler handler = ref.read(audioHandlerProvider);
    final bool wasEmpty = handler.queue.value.isEmpty;
    if (wasEmpty) {
      await handler.playAll(items);
    } else {
      await handler.addQueueItems(items);
    }
    messenger.showSnackBar(SnackBar(
      duration: kSnackBarDuration,
      content: Text(
        songs.length == 1
            ? (wasEmpty
                ? 'Playing: ${songs.first.title}'
                : 'Added to queue: ${songs.first.title}')
            : (wasEmpty
                ? 'Playing ${songs.length} songs'
                : 'Added ${songs.length} songs to queue'),
      ),
    ));
  } catch (e) {
    if (context.mounted) _errSnack(context, e);
  }
}

/// Play a list of Subsonic [Song]s, optionally starting at [startIndex].
/// Used by Album / Playlist "Play all" + Album tile's trailing play.
Future<void> playAllSongsFromSubsonic(
  WidgetRef ref,
  BuildContext context,
  List<Song> songs, {
  int startIndex = 0,
}) async {
  if (songs.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      duration: kSnackBarDuration,
      content: Text('Nothing to play.'),
    ));
    return;
  }
  try {
    final _Creds? creds = await _resolveCreds(ref);
    if (creds == null) {
      if (context.mounted) _credsMissingSnack(context);
      return;
    }
    final List<MediaItem> items = await Future.wait<MediaItem>(
      songs.map((Song s) => _toMediaItem(ref, s, creds)),
    );
    await ref
        .read(audioHandlerProvider)
        .playAll(items, startIndex: startIndex);
  } catch (e) {
    if (context.mounted) _errSnack(context, e);
  }
}

/// Resolve an Album by id and play all its songs. Used by Artist detail's
/// per-album trailing play and the library search section's Album play icon.
Future<void> playAlbumFromSubsonic(
  WidgetRef ref,
  BuildContext context,
  String albumId,
) async {
  try {
    final Album album = await ref.read(libraryAlbumProvider(albumId).future);
    if (!context.mounted) return;
    await playAllSongsFromSubsonic(ref, context, album.song);
  } catch (e) {
    if (context.mounted) _errSnack(context, e);
  }
}

/// Resolve an Artist by id and play every song from every album, in the
/// artist's album order (Subsonic's `getArtist` returns them most-recent
/// first by default; we keep that order so "Play all" feels like a
/// chronological walk-through of the artist's catalog without us
/// imposing an opinion on track ordering).
///
/// Album resolution fans out in parallel — for an artist with 20 albums
/// the serial walk would otherwise multiply the latency by 20.
Future<void> playArtistFromSubsonic(
  WidgetRef ref,
  BuildContext context,
  String artistId,
) async {
  try {
    final Artist artist =
        await ref.read(libraryArtistProvider(artistId).future);
    if (artist.album.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          duration: kSnackBarDuration,
          content: Text('No albums for this artist.'),
        ));
      }
      return;
    }
    final List<Album> resolved = await Future.wait<Album>(
      artist.album
          .map((Album a) => ref.read(libraryAlbumProvider(a.id).future)),
    );
    final List<Song> songs = <Song>[
      for (final Album a in resolved) ...a.song,
    ];
    if (!context.mounted) return;
    await playAllSongsFromSubsonic(ref, context, songs);
  } catch (e) {
    if (context.mounted) _errSnack(context, e);
  }
}

/// Resolve a Playlist by id and play all its entries.
Future<void> playPlaylistFromSubsonic(
  WidgetRef ref,
  BuildContext context,
  String playlistId,
) async {
  try {
    final Playlist p =
        await ref.read(libraryPlaylistProvider(playlistId).future);
    if (!context.mounted) return;
    await playAllSongsFromSubsonic(ref, context, p.entry);
  } catch (e) {
    if (context.mounted) _errSnack(context, e);
  }
}

/// Play a done ingestion job by mapping its output file to a Navidrome song
/// via Subsonic `search3`. Used by the Queue screen's per-done-job play
/// action.
///
/// Strategy: try a ranked list of candidate queries — `displayName` first
/// (cleanest, matches what the user typed/saw), then the bare `outputPath`
/// basename without extension. For each candidate we hit `search3` once
/// and take the first `Song` hit. We **don't** require an exact-1 match —
/// Subsonic returns fuzzy hits ordered by relevance, so the first hit is
/// almost always the right one. Only when every candidate yields zero
/// hits do we surface "Not in library yet" (re-index pending).
Future<void> playJobDoneFromSubsonic(
  WidgetRef ref,
  BuildContext context,
  JobView job,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  try {
    final List<String> candidates = _jobSearchCandidates(job);
    if (candidates.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        duration: kSnackBarDuration,
        content: Text("Can't search — job has no output path or title."),
      ));
      return;
    }
    final Dio dio = await ref.read(subsonicDioClientProvider.future);
    for (final String query in candidates) {
      final SearchResult3 result = await subsonicCall<SearchResult3>(
        () => dio.get<dynamic>(
          SubsonicEndpoints.search3,
          queryParameters: <String, dynamic>{'query': query},
        ),
        (Map<String, dynamic> env) {
          final dynamic payload = env['searchResult3'];
          if (payload is! Map<String, dynamic>) {
            return const SearchResult3();
          }
          return SearchResult3.fromJson(payload);
        },
      );
      if (!context.mounted) return;
      if (result.song.isNotEmpty) {
        await playSongFromSubsonic(ref, context, result.song.first);
        return;
      }
    }
    messenger.showSnackBar(const SnackBar(
      duration: kSnackBarDuration,
      content: Text('Not in library yet — try again in a minute.'),
    ));
  } catch (e) {
    if (context.mounted) _errSnack(context, e);
  }
}

/// Ordered list of search3 queries to try for a done job. De-duped + empties
/// dropped. Prefers `displayName` over the filesystem basename — the
/// basename can include track-number prefixes, accent-stripped chars, or
/// other sanitisation that Subsonic's tokenizer doesn't reconcile with
/// the song's actual title in the index.
List<String> _jobSearchCandidates(JobView job) {
  final List<String> out = <String>[];
  void push(String? s) {
    if (s == null) return;
    final String t = s.trim();
    if (t.isEmpty) return;
    if (!out.contains(t)) out.add(t);
  }

  push(job.displayName);

  final String? path = job.outputPath;
  if (path != null && path.isNotEmpty) {
    final String basename = path.split('/').last;
    final int dot = basename.lastIndexOf('.');
    final String stem = dot > 0 ? basename.substring(0, dot) : basename;
    push(stem);
  }
  return out;
}
