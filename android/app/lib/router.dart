import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/job_detail_screen.dart';
import 'screens/library/album_detail_screen.dart';
import 'screens/library/artist_detail_screen.dart';
import 'screens/library/library_screen.dart';
import 'screens/library/playlist_detail_screen.dart';
import 'screens/player/now_playing_screen.dart';
import 'screens/queue_screen.dart';
import 'screens/servers_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/mini_player.dart';

// Route paths — kept as constants so widget tests and link callers don't
// drift apart. Settings is exposed via `/settings`; routing redirects to
// it when the bearer token is missing (wired at B1/B3 — not here).
class Routes {
  static const String library = '/';
  static const String queue = '/queue';
  static const String settings = '/settings';
  static const String servers = '/settings/servers';

  // Library detail (Subsonic via Navidrome). Nested under the library
  // route so the URL shape and the navigation hierarchy match.
  static String libraryArtist(String id) => '/library/artist/$id';
  static String libraryAlbum(String id) => '/library/album/$id';
  static String libraryPlaylist(String id) => '/library/playlist/$id';

  // Job-detail lands at D3; route shape defined here to lock the URL.
  static String job(String id) => '/job/$id';
}

/// Builds the app's `GoRouter`. Lives at module scope so widget tests can
/// reuse the exact router config the app boots with.
GoRouter buildHeerrRouter() {
  return GoRouter(
    initialLocation: Routes.library,
    routes: <RouteBase>[
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return _ShellScaffold(location: state.matchedLocation, child: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: Routes.library,
            builder: (BuildContext context, GoRouterState state) =>
                const LibraryScreen(),
            routes: <RouteBase>[
              GoRoute(
                path: 'library/artist/:id',
                builder: (BuildContext context, GoRouterState state) =>
                    ArtistDetailScreen(artistId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'library/album/:id',
                builder: (BuildContext context, GoRouterState state) =>
                    AlbumDetailScreen(albumId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'library/playlist/:id',
                builder: (BuildContext context, GoRouterState state) =>
                    PlaylistDetailScreen(
                        playlistId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: Routes.queue,
            builder: (BuildContext context, GoRouterState state) =>
                const QueueScreen(),
          ),
          GoRoute(
            path: Routes.settings,
            builder: (BuildContext context, GoRouterState state) =>
                const SettingsScreen(),
            routes: <RouteBase>[
              GoRoute(
                path: 'servers',
                builder: (BuildContext context, GoRouterState state) =>
                    const ServersScreen(),
              ),
            ],
          ),
        ],
      ),
      // Job-detail is outside the ShellRoute so it gets a focused full-screen
      // view with a normal back button (and no bottom nav stealing space).
      GoRoute(
        path: '/job/:id',
        builder: (BuildContext context, GoRouterState state) =>
            JobDetailScreen(jobId: state.pathParameters['id']!),
      ),
      // Now Playing — top-level so it pushes full-screen above the bottom nav.
      GoRoute(
        path: '/player',
        builder: (BuildContext context, GoRouterState state) =>
            const NowPlayingScreen(),
      ),
    ],
  );
}

// Bottom-nav shell. Wraps every child route with the same `NavigationBar` so
// tab switches don't tear down state inside the surrounding scaffold. The
// mini-player sits above the NavigationBar; it hides itself when nothing is
// queued.
class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold({required this.location, required this.child});

  final String location;
  final Widget child;

  static const List<_NavTab> _tabs = <_NavTab>[
    _NavTab(
      path: Routes.library,
      label: 'Library',
      icon: Icons.library_music_outlined,
      selectedIcon: Icons.library_music,
    ),
    _NavTab(
      path: Routes.queue,
      label: 'Queue',
      icon: Icons.queue_music_outlined,
      selectedIcon: Icons.queue_music,
    ),
    _NavTab(
      path: Routes.settings,
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];

  int _indexFor(String loc) {
    // Nested routes (e.g. /library/album/xxx, /settings/servers) belong
    // under their parent tab so the selected indicator stays in the right
    // place when the user drills into a detail screen.
    if (loc.startsWith('/library') || loc == Routes.library) return 0;
    if (loc.startsWith(Routes.queue)) return 1;
    if (loc.startsWith(Routes.settings)) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final int currentIndex = _indexFor(location);
    return Scaffold(
      body: child,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (int i) => context.go(_tabs[i].path),
            destinations: <NavigationDestination>[
              for (final _NavTab t in _tabs)
                NavigationDestination(
                  icon: Icon(t.icon),
                  selectedIcon: Icon(t.selectedIcon),
                  label: t.label,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavTab {
  const _NavTab({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
