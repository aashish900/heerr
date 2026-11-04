import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/subsonic_client.dart';
import '../models/subsonic/album.dart';
import '../models/subsonic/artist.dart';
import '../models/subsonic/artist_index.dart';
import '../models/subsonic/playlist.dart';
import '../models/subsonic/song.dart';
import '../providers/downloaded_songs.dart';
import '../providers/home/home_providers.dart';
import '../providers/library/favourites.dart';
import '../providers/library/library_album.dart';
import '../providers/library/library_albums.dart';
import '../providers/library/library_artist.dart';
import '../providers/library/library_artists.dart';
import '../providers/library/library_playlist.dart';
import '../providers/library/library_playlists.dart';
import '../providers/server_creds.dart';
import 'browse_ids.dart';

/// Android Auto truncates long lists and the car UI is a poor place to
/// scroll thousands of rows; cap every level.
// ponytail: flat cap, no paging; add `options` paging if libraries outgrow it.
const int kMaxBrowseItems = 200;

const int _kArtSize = 300;

const String _kBrowsableHint =
    'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT';
const int _kStyleGrid = 2;

/// Root extras for `AudioServiceConfig.androidBrowsableRootExtras`:
/// the car may use per-item style hints; browsable rows default to a list,
/// playable rows to a list.
const Map<String, dynamic> kBrowseRootExtras = <String, dynamic>{
  'android.media.browse.CONTENT_STYLE_SUPPORTED': true,
  _kBrowsableHint: 1,
  'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 1,
};

const List<(BrowseKind, String)> _tabs = <(BrowseKind, String)>[
  (BrowseKind.recents, 'Recents'),
  (BrowseKind.favourites, 'Favourites'),
  (BrowseKind.playlists, 'Playlists'),
  (BrowseKind.albums, 'Albums'),
  (BrowseKind.artists, 'Artists'),
  (BrowseKind.downloaded, 'Downloaded'),
];

/// Children of [parent] in the car browse tree, read through the app's
/// cache-aware library providers (so Downloaded and cached lists work
/// offline). Unknown / leaf nodes return `[]`; data tabs return `[]` when
/// there are no Navidrome creds.
Future<List<MediaItem>> browseChildren(
  ProviderContainer c,
  BrowseId parent,
) async {
  if (parent.kind == BrowseKind.root) return _tabItems();

  final ServerCreds creds = c.read(serverCredsProvider);
  final String? base = creds.navidromeBaseUrl;
  final String? user = creds.navidromeUsername;
  final String? pass = creds.navidromePassword;
  if (base == null ||
      base.isEmpty ||
      user == null ||
      user.isEmpty ||
      pass == null ||
      pass.isEmpty) {
    return <MediaItem>[];
  }

  Uri? art(String? coverArt) => coverArt == null || coverArt.isEmpty
      ? null
      : Uri.parse(
          buildSubsonicCoverArtUrl(
            baseUrl: base,
            username: user,
            password: pass,
            coverArtId: coverArt,
            size: _kArtSize,
          ),
        );

  List<MediaItem> albums(Iterable<Album> xs) => <MediaItem>[
    for (final Album a in xs.take(kMaxBrowseItems))
      MediaItem(
        id: BrowseId(BrowseKind.album, a.id).encoded,
        title: a.name,
        artist: a.artist,
        artUri: art(a.coverArt),
        playable: false,
      ),
  ];

  List<MediaItem> songs(Iterable<Song> xs) => <MediaItem>[
    for (final Song s in xs.take(kMaxBrowseItems))
      MediaItem(
        id: BrowseId(BrowseKind.song, s.id, parent).encoded,
        title: s.title,
        artist: s.artist,
        album: s.album,
        duration: s.duration == null ? null : Duration(seconds: s.duration!),
        artUri: art(s.coverArt),
        extras: <String, dynamic>{'subsonicId': s.id},
      ),
  ];

  switch (parent.kind) {
    case BrowseKind.recents:
      return albums(await c.read(recentlyPlayedProvider.future));
    case BrowseKind.albums:
      return albums(await c.read(libraryAlbumsProvider.future));
    case BrowseKind.artists:
      final List<ArtistIndex> index = await c.read(
        libraryArtistsProvider.future,
      );
      return <MediaItem>[
        for (final Artist a in <Artist>[
          for (final ArtistIndex i in index) ...i.artist,
        ].take(kMaxBrowseItems))
          MediaItem(
            id: BrowseId(BrowseKind.artist, a.id).encoded,
            title: a.name,
            artUri: art(a.coverArt),
            playable: false,
          ),
      ];
    case BrowseKind.playlists:
      final List<Playlist> ps = await c.read(libraryPlaylistsProvider.future);
      return <MediaItem>[
        for (final Playlist p in ps.take(kMaxBrowseItems))
          MediaItem(
            id: BrowseId(BrowseKind.playlist, p.id).encoded,
            title: p.name,
            artUri: art(p.coverArt),
            playable: false,
          ),
      ];
    case BrowseKind.favourites:
    case BrowseKind.downloaded:
    case BrowseKind.album:
    case BrowseKind.playlist:
      return songs(await songsOf(c, parent));
    case BrowseKind.artist:
      return albums(
        (await c.read(libraryArtistProvider(parent.id!).future)).album,
      );
    case BrowseKind.root:
    case BrowseKind.song:
      return <MediaItem>[];
  }
}

List<MediaItem> _tabItems() => <MediaItem>[
  for (final (BrowseKind kind, String title) in _tabs)
    MediaItem(
      id: BrowseId(kind).encoded,
      title: title,
      playable: false,
      extras: <String, dynamic>{
        if (kind == BrowseKind.albums || kind == BrowseKind.artists)
          _kBrowsableHint: _kStyleGrid,
      },
    ),
];

/// Songs directly under a song-bearing node (favourites, downloaded, album,
/// playlist); `[]` for every other kind. Shared by browsing and
/// `playFromMediaId` so both see the same list.
Future<List<Song>> songsOf(ProviderContainer c, BrowseId node) async {
  switch (node.kind) {
    case BrowseKind.favourites:
      final Playlist? fav = await c.read(favouritesPlaylistProvider.future);
      if (fav == null) return <Song>[];
      return (await c.read(libraryPlaylistProvider(fav.id).future)).entry;
    case BrowseKind.downloaded:
      return c.read(downloadedSongsProvider.future);
    case BrowseKind.album:
      return (await c.read(libraryAlbumProvider(node.id!).future)).song;
    case BrowseKind.playlist:
      return (await c.read(libraryPlaylistProvider(node.id!).future)).entry;
    default:
      return <Song>[];
  }
}
