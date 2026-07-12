import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:heerr/models/profile.dart';
import 'package:heerr/models/subsonic/album.dart';
import 'package:heerr/models/subsonic/artist.dart';
import 'package:heerr/models/subsonic/artist_index.dart';
import 'package:heerr/models/subsonic/playlist.dart';
import 'package:heerr/providers/library/library_albums.dart';
import 'package:heerr/providers/library/library_artists.dart';
import 'package:heerr/providers/library/library_playlists.dart';
import 'package:heerr/providers/prefs_storage.dart';
import 'package:heerr/providers/profiles/active_profile.dart';
import 'package:heerr/providers/profiles/profile_avatar.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/router.dart';
import 'package:heerr/screens/library/favorites_screen.dart';
import 'package:heerr/screens/library/recently_played_screen.dart';
import 'package:heerr/services/backend_service.dart';

/// Regression tests for the Profile "My Music" rows against the REAL app
/// router (`buildHeerrRouter`), reached the way the app actually reaches
/// /profile: an imperative `push` from the Home avatar.
///
/// The original coverage in `profile_screen_test.dart` used a flat stub
/// router where `/library/favorites` was a top-level route, which hid a
/// go_router 14.8.1 crash: `push`ing a ShellRoute-nested location while the
/// current top of stack is an imperatively-pushed non-shell route throws a
/// duplicated-page-key assertion (`!keyReservation.contains(key)`) — on a
/// release device the tap silently does nothing. The fix routes these rows
/// through `context.go` (like the Downloads / Playlists / Settings rows).
class _FakePrefs implements PrefsStorage {
  final Map<String, String> store = <String, String>{};
  @override
  Future<String?> read(String key) async => store[key];
  @override
  Future<void> write(String key, String value) async => store[key] = value;
  @override
  Future<void> delete(String key) async => store.remove(key);
}

class _FakeSecureStorage implements SecureStorage {
  final Map<String, String> store = <String, String>{};
  @override
  Future<String?> read(String key) async => store[key];
  @override
  Future<void> write(String key, String value) async => store[key] = value;
  @override
  Future<void> delete(String key) async => store.remove(key);
}

Profile _profile() => Profile(
      id: 'p1',
      displayName: 'Alice',
      heerrBaseUrl: 'http://h',
      heerrBearerToken: 't',
      navidromeBaseUrl: 'http://n',
      navidromeUsername: 'alice-nd',
      navidromePassword: 'pw',
      createdAt: DateTime.utc(2026),
      lastUsedAt: DateTime.utc(2026),
    );

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('profile_nav'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<GoRouter> pumpAtPushedProfile(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final GoRouter router = buildHeerrRouter();
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        prefsStorageProvider.overrideWithValue(_FakePrefs()),
        secureStorageProvider.overrideWith(
          (Ref<SecureStorage> _) => _FakeSecureStorage(),
        ),
        activeProfileProvider.overrideWithValue(_profile()),
        avatarsDirProvider.overrideWith((_) async => tmp),
        backendServiceProvider.overrideWith(
          (BackendServiceRef ref) async => BackendService(Dio()),
        ),
        libraryPlaylistsProvider.overrideWith(
          (LibraryPlaylistsRef ref) async => <Playlist>[
            const Playlist(id: '1', name: 'Favourites', owner: 'alice-nd'),
          ],
        ),
        libraryAlbumsProvider.overrideWith(
          (LibraryAlbumsRef ref) async => <Album>[
            const Album(id: '1', name: 'Al1', songCount: 12),
          ],
        ),
        libraryArtistsProvider.overrideWith(
          (LibraryArtistsRef ref) async => <ArtistIndex>[
            const ArtistIndex(name: 'A', artist: <Artist>[
              Artist(id: '1', name: 'Artist One'),
            ]),
          ],
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump();
    router.go('/');
    await tester.pump(const Duration(milliseconds: 300));
    // On-device path: the Home avatar pushes /profile imperatively.
    unawaited(router.push('/profile'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    return router;
  }

  testWidgets('Liked Songs opens FavoritesScreen from a pushed /profile',
      (WidgetTester tester) async {
    await pumpAtPushedProfile(tester);

    await tester.ensureVisible(
      find.byKey(const Key('profile-row-liked-songs')),
    );
    await tester.tap(find.byKey(const Key('profile-row-liked-songs')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(FavoritesScreen), findsOneWidget);
  });

  testWidgets(
      'Recently Played opens RecentlyPlayedScreen from a pushed /profile',
      (WidgetTester tester) async {
    await pumpAtPushedProfile(tester);

    await tester.ensureVisible(
      find.byKey(const Key('profile-row-recently-played')),
    );
    await tester.tap(find.byKey(const Key('profile-row-recently-played')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(RecentlyPlayedScreen), findsOneWidget);
  });
}
