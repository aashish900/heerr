import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dio/dio.dart';

import '../api/api_error.dart';
import '../api/subsonic_client.dart';
import '../api/subsonic_endpoints.dart';
import '../models/job_view.dart';
import '../models/subsonic/album.dart';
import '../models/subsonic/playlist.dart';
import '../models/subsonic/search_result3.dart';
import '../models/subsonic/song.dart';
import '../providers/library/library_album.dart';
import '../providers/library/library_playlist.dart';
import '../providers/settings.dart';
import 'player_provider.dart';
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
  final SettingsValue settings = await ref.read(settingsProvider.future);
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
    content: Text(
      'Navidrome creds missing — fill them in under Settings → Servers',
    ),
  ));
}

void _errSnack(BuildContext context, Object e) {
  final String msg = e is ApiError ? e.message : 'Play failed: $e';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

MediaItem _toMediaItem(Song s, _Creds c) => songToMediaItem(
      song: s,
      navidromeBaseUrl: c.url,
      navidromeUsername: c.user,
      navidromePassword: c.pass,
    );

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
    final MediaItem item = _toMediaItem(song, creds);
    await ref.read(audioHandlerProvider).playSong(item);
    messenger.showSnackBar(SnackBar(
      content: Text('Playing: ${song.title}'),
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
    final List<MediaItem> items =
        songs.map((Song s) => _toMediaItem(s, creds)).toList();
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
/// Strategy: query string is the basename of `outputPath` (extension
/// stripped). If `outputPath` is absent we fall back to `displayName`.
/// Subsonic `search3` returns up to 20 songs; we require **exactly one**
/// hit so we don't accidentally play the wrong track when titles collide.
/// On ambiguity or zero hits we surface a "Not in library yet" snackbar —
/// usually the re-index is still pending (typical lag ~30–60s).
Future<void> playJobDoneFromSubsonic(
  WidgetRef ref,
  BuildContext context,
  JobView job,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  try {
    final String? query = _jobSearchQuery(job);
    if (query == null || query.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text("Can't search — job has no output path or title."),
      ));
      return;
    }
    final Dio dio = await ref.read(subsonicDioClientProvider.future);
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
    if (result.song.length != 1) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Not in library yet — try again in a minute.'),
      ));
      return;
    }
    await playSongFromSubsonic(ref, context, result.song.first);
  } catch (e) {
    if (context.mounted) _errSnack(context, e);
  }
}

String? _jobSearchQuery(JobView job) {
  final String? path = job.outputPath;
  if (path != null && path.isNotEmpty) {
    final String basename = path.split('/').last;
    final int dot = basename.lastIndexOf('.');
    return dot > 0 ? basename.substring(0, dot) : basename;
  }
  return job.displayName;
}
