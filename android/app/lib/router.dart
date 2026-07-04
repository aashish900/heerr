import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'app/lifecycle_coordinator.dart';
import 'providers/library/library_search_query.dart';
import 'providers/profiles/profile_registry.dart';
import 'screens/auth/login_screen.dart';
import 'screens/downloads_screen.dart';
import 'screens/job_detail_screen.dart';
import 'screens/library/album_detail_screen.dart';
import 'screens/library/artist_detail_screen.dart';
import 'screens/library/library_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/library/playlist_detail_screen.dart';
import 'screens/player/now_playing_screen.dart';
import 'screens/queue_screen.dart';
import 'screens/recommendations_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/mini_player.dart';

// Route paths — kept as constants so widget tests and link callers don't
// drift apart. Settings is exposed via `/settings`; routing redirects to
// it when the bearer token is missing (wired at B1/B3 — not here).
class Routes {
  static const String home = '/';
  static const String library = '/library';
  static const String downloads = '/downloads';
  static const String queue = '/queue';
  static const String settings = '/settings';
  static const String login = '/login';

  // Library detail (Subsonic via Navidrome). Nested under the library
  // route so the URL shape and the navigation hierarchy match.
  static String libraryArtist(String id) => '/library/artist/$id';
  static String libraryAlbum(String id) => '/library/album/$id';
  static String libraryPlaylist(String id) => '/library/playlist/$id';
  static const String libraryRecommendations = '/library/recommendations';

  // Job-detail lands at D3; route shape defined here to lock the URL.
  static String job(String id) => '/job/$id';
}

/// Builds the app's `GoRouter`. Lives at module scope so widget tests can
/// reuse the exact router config the app boots with.
///
/// [container] (optional) wires the S5 first-launch redirect: when no
/// profile is active, every navigation outside `/login` is rewritten to
/// `/login`. Tests that don't exercise the redirect can omit it.
GoRouter buildHeerrRouter({ProviderContainer? container}) {
  // A2: without a refreshListenable the redirect only re-runs on navigation
  // events, so deleting the active profile leaves stale screens rendered
  // against a torn-down profile until the user taps a tab. Bridging the
  // registry provider to a Listenable makes GoRouter re-evaluate the redirect
  // (→ /login) the instant the active profile becomes null.
  final _RouterRefresh? refresh = container == null
      ? null
      : _RouterRefresh(container);
  return GoRouter(
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: container == null
        ? null
        : (BuildContext context, GoRouterState state) {
            final AsyncValue<ProfileRegistryState> async = container.read(
              profileRegistryProvider,
            );
            final ProfileRegistryState? value = async.valueOrNull;
            // While the registry is still loading, don't redirect — let
            // the destination screen render a loading state.
            if (value == null) return null;
            // First-launch / signed-out: rewrite everything except
            // /login to /login. The reverse (active-profile + at-/login
            // → Home) is intentionally NOT applied so the "Add profile"
            // button can push /login while a profile is already active.
            // The LoginScreen navigates to / itself on successful
            // submit; there's no loop risk.
            final bool atLogin = state.matchedLocation == Routes.login;
            if (value.activeId == null && !atLogin) return Routes.login;
            return null;
          },
    routes: <RouteBase>[
      GoRoute(
        path: Routes.login,
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
      ),
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          // A8: the lifecycle host wraps the nav chrome. The shell stays a
          // pure layout widget; all AppLifecycleState side-effects live in
          // LifecycleCoordinator.
          return LifecycleCoordinator(
            child: _ShellScaffold(
              location: state.matchedLocation,
              child: child,
            ),
          );
        },
        routes: <RouteBase>[
          GoRoute(
            path: Routes.home,
            builder: (BuildContext context, GoRouterState state) =>
                const HomeScreen(),
          ),
          GoRoute(
            path: Routes.library,
            builder: (BuildContext context, GoRouterState state) =>
                const LibraryScreen(),
            routes: <RouteBase>[
              GoRoute(
                path: 'artist/:id',
                builder: (BuildContext context, GoRouterState state) =>
                    ArtistDetailScreen(artistId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'album/:id',
                builder: (BuildContext context, GoRouterState state) =>
                    AlbumDetailScreen(albumId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'playlist/:id',
                builder: (BuildContext context, GoRouterState state) =>
                    PlaylistDetailScreen(
                      playlistId: state.pathParameters['id']!,
                    ),
              ),
              GoRoute(
                path: 'recommendations',
                builder: (BuildContext context, GoRouterState state) =>
                    const RecommendationsScreen(),
              ),
            ],
          ),
          GoRoute(
            path: Routes.queue,
            builder: (BuildContext context, GoRouterState state) =>
                const QueueScreen(),
          ),
          GoRoute(
            path: Routes.downloads,
            builder: (BuildContext context, GoRouterState state) =>
                const DownloadsScreen(),
          ),
          GoRoute(
            path: Routes.settings,
            builder: (BuildContext context, GoRouterState state) =>
                const SettingsScreen(),
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

/// Bridges [profileRegistryProvider] to a [Listenable] for GoRouter's
/// `refreshListenable` (A2). Notifies on every registry change so the
/// first-launch / signed-out redirect re-evaluates immediately — most
/// importantly when the active profile is removed and `activeId` goes null.
///
/// The `container.listen` subscription is auto-closed when the container is
/// disposed (app teardown / test tear-down), and GoRouter removes its own
/// listener on `dispose()`, so this needs no explicit disposal.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(ProviderContainer container) {
    container.listen<AsyncValue<ProfileRegistryState>>(
      profileRegistryProvider,
      (_, _) => notifyListeners(),
    );
  }
}

// Bottom-nav shell. Wraps every child route with the same `NavigationBar` so
// tab switches don't tear down state inside the surrounding scaffold. The
// mini-player sits above the NavigationBar; it hides itself when nothing is
// queued.
//
// A8: the lifecycle host that used to live here is now LifecycleCoordinator
// (lib/app/lifecycle_coordinator.dart). This widget is pure nav chrome.
class _ShellScaffold extends ConsumerStatefulWidget {
  const _ShellScaffold({required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  ConsumerState<_ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends ConsumerState<_ShellScaffold> {

  static const List<_NavTab> _tabs = <_NavTab>[
    _NavTab(
      path: Routes.home,
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    _NavTab(
      path: Routes.library,
      label: 'Library',
      // Custom 3D-stack icon (`assets/icons/library.svg`, sourced from
      // the brand-feeling Spotify-style mark). `null` icon fields mark
      // that this tab renders via [_buildLibraryIcon] / -selected.
      icon: null,
      selectedIcon: null,
    ),
    _NavTab(
      path: Routes.downloads,
      label: 'Downloads',
      icon: Icons.download_for_offline_outlined,
      selectedIcon: Icons.download_for_offline,
    ),
    _NavTab(
      path: Routes.settings,
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];

  /// Renders the Library tab icon from the bundled SVG. Tinted to match
  /// the active NavigationBar icon-theme color so it follows the M3
  /// selected / unselected states without hard-coding a palette.
  Widget _buildLibraryIcon(BuildContext context, {required bool selected}) {
    final IconThemeData theme = selected
        ? NavigationBarTheme.of(
                context,
              ).iconTheme?.resolve(<WidgetState>{WidgetState.selected}) ??
              IconTheme.of(context)
        : IconTheme.of(context);
    final Color tint = theme.color ?? Theme.of(context).colorScheme.onSurface;
    return SvgPicture.asset(
      'assets/icons/library.svg',
      width: 24,
      height: 24,
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
    );
  }

  int _indexFor(String loc) {
    // Library detail routes live under /library/* — they keep the Library tab
    // selected. Queue is reachable via the Home AppBar shortcut, so when
    // /queue is active no tab is "selected"; we still highlight Home as the
    // most-recently-rooted-in tab to avoid a confusing blank state.
    if (loc.startsWith(Routes.library)) return 1;
    if (loc.startsWith(Routes.downloads)) return 2;
    if (loc.startsWith(Routes.settings)) return 3;
    return 0;
  }

  /// Library uses an SVG asset; every other tab is a Material `IconData`.
  /// Returns null when the tab has no `IconData` set (i.e. Library).
  Widget _iconFor(BuildContext context, _NavTab tab, {required bool selected}) {
    if (tab.icon == null) {
      return _buildLibraryIcon(context, selected: selected);
    }
    return Icon(selected ? tab.selectedIcon : tab.icon);
  }

  @override
  Widget build(BuildContext context) {
    final int currentIndex = _indexFor(widget.location);

    return PopScope(
      canPop: widget.location == Routes.home,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;

        if (widget.location == Routes.library &&
            ref.read(librarySearchActiveProvider)) {
          ref.read(librarySearchActiveProvider.notifier).set(false);
          return;
        }

        if (widget.location != Routes.home) {
          context.go(Routes.home);
        }
      },
      child: Scaffold(
        body: widget.child,
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
                    icon: _iconFor(context, t, selected: false),
                    selectedIcon: _iconFor(context, t, selected: true),
                    label: t.label,
                  ),
              ],
            ),
          ],
        ),
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

  /// `null` opts into a custom-drawn widget for this tab — see the
  /// `_buildLibraryIcon` branch in `_ShellScaffoldState.build`.
  final IconData? icon;
  final IconData? selectedIcon;
}
