import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/album.dart';
import 'package:heerr/models/subsonic/artist.dart';
import 'package:heerr/models/subsonic/artist_index.dart';
import 'package:heerr/models/subsonic/playlist.dart';
import 'package:heerr/models/subsonic/search_result3.dart';
import 'package:heerr/models/subsonic/song.dart';

Map<String, dynamic> _loadFixture(String name) {
  final File file = File('test/fixtures/subsonic/$name');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

Map<String, dynamic> _envelope(Map<String, dynamic> response) {
  return response['subsonic-response'] as Map<String, dynamic>;
}

void main() {
  group('Song', () {
    test('round-trips a fully-populated song fixture', () {
      final Map<String, dynamic> env =
          _envelope(_loadFixture('get_album.json'));
      final List<dynamic> songs =
          (env['album'] as Map<String, dynamic>)['song'] as List<dynamic>;
      final Map<String, dynamic> songJson =
          songs.first as Map<String, dynamic>;

      final Song parsed = Song.fromJson(songJson);

      expect(parsed.id, 'so-1001');
      expect(parsed.title, 'Let It Happen');
      expect(parsed.artist, 'Tame Impala');
      expect(parsed.artistId, 'ar-002');
      expect(parsed.album, 'Currents');
      expect(parsed.albumId, 'al-101');
      expect(parsed.coverArt, 'al-101');
      expect(parsed.duration, 467);
      expect(parsed.track, 1);
      expect(parsed.year, 2015);
      expect(parsed.bitRate, 320);
      expect(parsed.contentType, 'audio/mpeg');
      expect(parsed.isVideo, false);

      // Round-trip identity: toJson → fromJson → equals.
      final Song again = Song.fromJson(parsed.toJson());
      expect(again, parsed);
    });

    test('camelCase fields survive the global field_rename: snake', () {
      // The project-global build.yaml renames Dart camelCase → wire
      // snake_case for every json_serializable model. Subsonic models opt
      // out via per-field @JsonKey(name: 'camelCase'). This test guards
      // against a future contributor dropping the annotations.
      final Song s = Song.fromJson(<String, dynamic>{
        'id': 'x',
        'title': 't',
        'artistId': 'A',
        'albumId': 'B',
        'coverArt': 'C',
        'contentType': 'audio/mpeg',
        'bitRate': 192,
        'isVideo': false,
      });
      expect(s.artistId, 'A');
      expect(s.albumId, 'B');
      expect(s.coverArt, 'C');
      expect(s.contentType, 'audio/mpeg');
      expect(s.bitRate, 192);
      expect(s.isVideo, false);

      final Map<String, dynamic> back = s.toJson();
      expect(back['artistId'], 'A');
      expect(back['albumId'], 'B');
      expect(back['coverArt'], 'C');
      expect(back['contentType'], 'audio/mpeg');
      expect(back['bitRate'], 192);
      expect(back['isVideo'], false);
    });
  });

  group('Artist + ArtistIndex (getArtists)', () {
    test('round-trips one ArtistIndex from the getArtists fixture', () {
      final Map<String, dynamic> env =
          _envelope(_loadFixture('get_artists.json'));
      final List<dynamic> indices =
          (env['artists'] as Map<String, dynamic>)['index'] as List<dynamic>;

      final ArtistIndex first =
          ArtistIndex.fromJson(indices.first as Map<String, dynamic>);
      expect(first.name, 'A');
      expect(first.artist, hasLength(1));
      expect(first.artist.first.name, 'Arctic Monkeys');
      expect(first.artist.first.albumCount, 6);

      final ArtistIndex again = ArtistIndex.fromJson(first.toJson());
      expect(again, first);
    });
  });

  group('Album (with song list from getAlbum)', () {
    test('round-trips an album fixture with three songs', () {
      final Map<String, dynamic> env =
          _envelope(_loadFixture('get_album.json'));
      final Album album = Album.fromJson(env['album'] as Map<String, dynamic>);

      expect(album.id, 'al-101');
      expect(album.name, 'Currents');
      expect(album.artist, 'Tame Impala');
      expect(album.artistId, 'ar-002');
      expect(album.songCount, 3);
      expect(album.duration, 720);
      expect(album.year, 2015);
      expect(album.song, hasLength(3));
      expect(album.song.first.title, 'Let It Happen');

      final Album again = Album.fromJson(album.toJson());
      expect(again, album);
    });

    test('album with no `song` key parses with empty song list', () {
      final Album a = Album.fromJson(<String, dynamic>{
        'id': 'al-x',
        'name': 'X',
      });
      expect(a.song, isEmpty);
    });
  });

  group('Artist detail (with album list from getArtist)', () {
    test('round-trips a getArtist fixture with two albums', () {
      final Map<String, dynamic> env =
          _envelope(_loadFixture('get_artist.json'));
      final Artist artist =
          Artist.fromJson(env['artist'] as Map<String, dynamic>);

      expect(artist.id, 'ar-002');
      expect(artist.name, 'Tame Impala');
      expect(artist.album, hasLength(2));
      expect(artist.album.first.name, 'Currents');

      final Artist again = Artist.fromJson(artist.toJson());
      expect(again, artist);
    });

    test('artist with no `album` key parses with empty album list', () {
      final Artist a = Artist.fromJson(<String, dynamic>{
        'id': 'x',
        'name': 'X',
      });
      expect(a.album, isEmpty);
    });
  });

  group('Playlist (with entry list from getPlaylist)', () {
    test('round-trips a getPlaylist fixture with two entries', () {
      final Map<String, dynamic> env =
          _envelope(_loadFixture('get_playlist.json'));
      final Playlist playlist =
          Playlist.fromJson(env['playlist'] as Map<String, dynamic>);

      expect(playlist.id, 'pl-01');
      expect(playlist.name, 'Morning Coffee');
      expect(playlist.owner, 'phone');
      expect(playlist.public, false);
      expect(playlist.entry, hasLength(2));
      expect(playlist.entry.first.title, 'Let It Happen');

      final Playlist again = Playlist.fromJson(playlist.toJson());
      expect(again, playlist);
    });

    test('getPlaylists summary parses without `entry` populated', () {
      final Map<String, dynamic> env =
          _envelope(_loadFixture('get_playlists.json'));
      final List<dynamic> list =
          (env['playlists'] as Map<String, dynamic>)['playlist']
              as List<dynamic>;

      final Playlist first =
          Playlist.fromJson(list.first as Map<String, dynamic>);
      expect(first.id, 'pl-01');
      expect(first.name, 'Morning Coffee');
      expect(first.entry, isEmpty);
    });
  });

  group('SearchResult3', () {
    test('round-trips a search3 fixture with all three sections populated', () {
      final Map<String, dynamic> env = _envelope(_loadFixture('search3.json'));
      final SearchResult3 result =
          SearchResult3.fromJson(env['searchResult3'] as Map<String, dynamic>);

      expect(result.artist, hasLength(1));
      expect(result.album, hasLength(1));
      expect(result.song, hasLength(1));
      expect(result.song.first.title, 'Let It Happen');

      final SearchResult3 again = SearchResult3.fromJson(result.toJson());
      expect(again, result);
    });

    test('empty payload (no artist/album/song keys) → empty sections', () {
      final SearchResult3 r = SearchResult3.fromJson(<String, dynamic>{});
      expect(r.artist, isEmpty);
      expect(r.album, isEmpty);
      expect(r.song, isEmpty);
    });
  });
}
