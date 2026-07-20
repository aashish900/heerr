import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/models/profile.dart';
import 'package:heerr/models/profile_meta.dart';
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
import 'package:heerr/providers/profiles/profile_registry.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/screens/profile/profile_screen.dart';
import 'package:heerr/services/backend_service.dart';

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

class _RecordingBackendService extends BackendService {
  _RecordingBackendService({this.throwOnLogout = false}) : super(Dio());

  final bool throwOnLogout;
  int logoutCalls = 0;

  @override
  Future<void> logout() async {
    logoutCalls++;
    if (throwOnLogout) throw const NetworkError();
  }
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
  setUp(() => tmp = Directory.systemTemp.createTempSync('profile_display'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Widget wrap({
    ProfileMeta? meta,
    Profile? profile,
    _FakeSecureStorage? secure,
    _RecordingBackendService? backend,
  }) {
    final _FakePrefs prefs = _FakePrefs();
    final Profile p = profile ?? _profile();
    if (meta != null) {
      prefs.store['profile_meta_${p.id}'] = jsonEncode(meta.toJson());
    }
    final _FakeSecureStorage kv = secure ?? _FakeSecureStorage();
    // A minimal router so the pencil badge's push target is assertable
    // without booting the whole app router.
    final GoRouter router = GoRouter(
      initialLocation: '/profile',
      routes: <RouteBase>[
        GoRoute(
          path: '/profile',
          builder: (BuildContext context, GoRouterState state) =>
              const ProfileScreen(),
          routes: <RouteBase>[
            GoRoute(
              path: 'edit',
              builder: (BuildContext context, GoRouterState state) =>
                  const Scaffold(body: Text('EDIT_SCREEN')),
            ),
          ],
        ),
        GoRoute(
          path: '/library/favorites',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('FAVORITES_SCREEN')),
        ),
        GoRoute(
          path: '/library/recently-played',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('RECENTLY_PLAYED_SCREEN')),
        ),
        GoRoute(
          path: '/library',
          builder: (BuildContext context, GoRouterState state) => Scaffold(
            body: Text('LIBRARY_SCREEN tab=${state.uri.queryParameters['tab']}'),
          ),
        ),
        GoRoute(
          path: '/downloads',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('DOWNLOADS_SCREEN')),
        ),
        GoRoute(
          path: '/settings',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('SETTINGS_SCREEN')),
        ),
        GoRoute(
          path: '/podcasts/subscriptions',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('PODCASTS_SCREEN')),
        ),
      ],
    );
    return ProviderScope(
      overrides: <Override>[
        prefsStorageProvider.overrideWithValue(prefs),
        secureStorageProvider.overrideWith((Ref<SecureStorage> _) => kv),
        activeProfileProvider.overrideWithValue(p),
        avatarsDirProvider.overrideWith((_) async => tmp),
        backendServiceProvider.overrideWith(
          (BackendServiceRef ref) async =>
              backend ?? _RecordingBackendService(),
        ),
        libraryPlaylistsProvider.overrideWith(
          (LibraryPlaylistsRef ref) async => <Playlist>[
            const Playlist(id: '1', name: 'A'),
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
    );
  }

  testWidgets('renders name, @handle and bio from profile + meta',
      (WidgetTester tester) async {
    await tester.pumpWidget(
        wrap(meta: const ProfileMeta(bio: 'Music is life. Play it loud.')));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('@alice-nd'), findsOneWidget);
    expect(find.text('Music is life. Play it loud.'), findsOneWidget);
  });

  testWidgets('bio line is hidden when meta has no bio',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-bio')), findsNothing);
    expect(find.text('@alice-nd'), findsOneWidget);
  });

  testWidgets('placeholder person icon renders when no avatar file exists',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });

  testWidgets('pencil badge pushes /profile/edit',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile-edit-badge')));
    await tester.pumpAndSettle();

    expect(find.text('EDIT_SCREEN'), findsOneWidget);
  });

  testWidgets('avatar tap also pushes /profile/edit',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile-avatar')));
    await tester.pumpAndSettle();

    expect(find.text('EDIT_SCREEN'), findsOneWidget);
  });

  testWidgets('stats row renders playlist/song/album/artist counts',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('1'), findsNWidgets(3)); // playlists, albums, artists
    expect(find.text('12'), findsOneWidget); // songs
    expect(
      find.descendant(
        of: find.byKey(const Key('profile-stat-playlists')),
        matching: find.text('Playlists'),
      ),
      findsOneWidget,
    );
    expect(find.text('Songs'), findsOneWidget);
    expect(find.text('Albums'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('profile-stat-artists')),
        matching: find.text('Artists'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Liked Songs card pushes /library/favorites',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-row-liked-songs')));
    await tester.pumpAndSettle();
    expect(find.text('FAVORITES_SCREEN'), findsOneWidget);
  });

  testWidgets('Downloaded card goes to /downloads',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-row-downloaded')));
    await tester.pumpAndSettle();
    expect(find.text('DOWNLOADS_SCREEN'), findsOneWidget);
  });

  testWidgets('Recently Played card pushes /library/recently-played',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-row-recently-played')));
    await tester.pumpAndSettle();
    expect(find.text('RECENTLY_PLAYED_SCREEN'), findsOneWidget);
  });

  testWidgets('Playlists card goes to /library?tab=playlists',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-row-playlists')));
    await tester.pumpAndSettle();
    expect(find.text('LIBRARY_SCREEN tab=playlists'), findsOneWidget);
  });

  testWidgets('Podcasts card pushes /podcasts/subscriptions',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-row-podcasts')));
    await tester.pumpAndSettle();
    expect(find.text('PODCASTS_SCREEN'), findsOneWidget);
  });

  testWidgets('Settings card goes to /settings', (WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const Key('profile-row-settings')), 300,
        scrollable: find.byType(Scrollable).first);
    // Scroll a bit further so the row clears the pinned AppBar — otherwise
    // "just barely visible" can still land under it and the tap misses.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -80));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-row-settings')));
    await tester.pumpAndSettle();
    expect(find.text('SETTINGS_SCREEN'), findsOneWidget);
  });

  testWidgets('Help & Support opens a dialog with Tailscale guidance',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const Key('profile-row-help')), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('profile-row-help')));
    await tester.pumpAndSettle();
    expect(find.text('Help & Support'), findsNWidgets(2)); // row + dialog title
    expect(find.textContaining('Tailscale'), findsOneWidget);
  });

  testWidgets('About heerr opens a dialog showing the app version',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const Key('profile-row-about')), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('profile-row-about')));
    await tester.pumpAndSettle();
    expect(find.text('About heerr'), findsNWidgets(2)); // row + dialog title
  });

  testWidgets('Log Out cancel dismisses without calling the backend',
      (WidgetTester tester) async {
    final _RecordingBackendService backend = _RecordingBackendService();
    await tester.pumpWidget(wrap(backend: backend));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
        find.byKey(const Key('profile-logout')), 300,
        scrollable: find.byType(Scrollable).first);
    // Same "clears the pinned AppBar" nudge as the Settings-card test.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -80));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-logout')));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(backend.logoutCalls, 0);
    expect(find.text('Log out?'), findsNothing); // dialog dismissed
    expect(find.byKey(const Key('profile-logout')), findsOneWidget);
  });

  testWidgets(
      'Log Out confirm calls the backend then clears the active profile pointer',
      (WidgetTester tester) async {
    final _FakeSecureStorage kv = _FakeSecureStorage();
    kv.store[kActiveProfileIdKey] = 'p1';
    final _RecordingBackendService backend = _RecordingBackendService();
    await tester.pumpWidget(wrap(secure: kv, backend: backend));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
        find.byKey(const Key('profile-logout')), 300,
        scrollable: find.byType(Scrollable).first);
    // Same "clears the pinned AppBar" nudge as the Settings-card test.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -80));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(backend.logoutCalls, 1);
    expect(kv.store.containsKey(kActiveProfileIdKey), isFalse);
  });

  testWidgets(
      'Log Out confirm still clears the active profile when the backend call fails',
      (WidgetTester tester) async {
    final _FakeSecureStorage kv = _FakeSecureStorage();
    kv.store[kActiveProfileIdKey] = 'p1';
    final _RecordingBackendService backend =
        _RecordingBackendService(throwOnLogout: true);
    await tester.pumpWidget(wrap(secure: kv, backend: backend));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
        find.byKey(const Key('profile-logout')), 300,
        scrollable: find.byType(Scrollable).first);
    // Same "clears the pinned AppBar" nudge as the Settings-card test.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -80));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(backend.logoutCalls, 1);
    expect(kv.store.containsKey(kActiveProfileIdKey), isFalse);
  });

  testWidgets('signed-out (null profile) renders an empty scaffold',
      (WidgetTester tester) async {
    final _FakePrefs prefs = _FakePrefs();
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        prefsStorageProvider.overrideWithValue(prefs),
        activeProfileProvider.overrideWithValue(null),
        avatarsDirProvider.overrideWith((_) async => tmp),
      ],
      child: const MaterialApp(home: ProfileScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-display-name')), findsNothing);
  });
}
