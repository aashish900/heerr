import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'offline/background_sync.dart';
import 'offline/offline_manifest.dart';
import 'offline/offline_settings.dart';
import 'offline/offline_sync.dart';
import 'player/now_playing_persistence.dart';
import 'providers/recommendations.dart';
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
import 'screens/servers_screen.dart';
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
  static const String servers = '/settings/servers';

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
GoRouter buildHeerrRouter() {
  return GoRouter(
    initialLocation: Routes.home,
    routes: <RouteBase>[
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return _ShellScaffold(location: state.matchedLocation, child: child);
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
                        playlistId: state.pathParameters['id']!),
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
//
// L3: also the lifecycle host for `offlineSyncProvider`. The shell is
// always mounted while the app is foregrounded — Settings is a child
// route, not a peer — so this is the right place to forward
// AppLifecycleState changes into pause()/resume() on the sync provider.
class _ShellScaffold extends ConsumerStatefulWidget {
  const _ShellScaffold({required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  ConsumerState<_ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends ConsumerState<_ShellScaffold>
    with WidgetsBindingObserver {
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
        ? NavigationBarTheme.of(context).iconTheme?.resolve(<WidgetState>{
              WidgetState.selected,
            }) ??
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Kick the offline sync provider so it builds + auto-syncs on app
    // launch. We don't watch it (would rebuild the shell on every status
    // change) — just trigger the build.
    Future<void>.microtask(() {
      if (!mounted) return;
      // ignore: unused_local_variable
      final dynamic _ = ref.read(offlineSyncProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Forward foreground/background transitions to the sync provider's
    // Timer. Matches the QueueScreen lifecycle pattern.
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        ref.read(offlineSyncProvider.notifier).pause();
        // P1: flush the Now Playing snapshot so position survives an
        // OS-may-kill-us next. Best-effort — async-fire-and-forget.
        unawaited(_flushNowPlaying());
        // Q3: hand off to the background worker. Skips when offline is off
        // or the manifest has no markers — the predicate lives inside
        // `onAppBackgrounded` so the lifecycle hook stays declarative.
        unawaited(_scheduleBackgroundSync());
      case AppLifecycleState.resumed:
        // Q3: cancel any in-flight background work so the foreground
        // notifier is the sole manifest writer while the app is visible —
        // no double-downloads. Fire-and-forget; resume() runs synchronously
        // below regardless of how the cancel completes.
        unawaited(_cancelBackgroundSync());
        unawaitedResume();
      case AppLifecycleState.detached:
        // App is fully detaching; the provider's onDispose will cancel the
        // timer when the container tears down.
        break;
    }
  }

  Future<void> _flushNowPlaying() async {
    try {
      final NowPlayingPersistence p =
          await ref.read(nowPlayingPersistenceProvider.future);
      await p.flush();
    } catch (_) {
      // Best-effort; swallow.
    }
  }

  void unawaitedResume() {
    // Fire-and-forget — resume() ticks immediately, but we don't need to
    // await it; failures land in the manifest's lastError.
    ref.read(offlineSyncProvider.notifier).resume();
    // N5: also re-check the recommendation engine's health on resume. The
    // notifier guards on a 60 s TTL so this is cheap to fire on every
    // foreground transition.
    ref.read(recommendHealthNotifierProvider.notifier).refreshIfStale();
  }

  Future<void> _cancelBackgroundSync() async {
    try {
      await onAppForegrounded(ref.read(backgroundSyncSchedulerProvider));
    } catch (_) {
      // Best-effort — the manifest is the source of truth either way.
    }
  }

  Future<void> _scheduleBackgroundSync() async {
    try {
      final OfflineSettingsValue? offline =
          ref.read(offlineSettingsProvider).valueOrNull;
      final OfflineManifest? manifest =
          ref.read(offlineManifestProvider).valueOrNull;
      if (offline == null || manifest == null) return;
      await onAppBackgrounded(
        scheduler: ref.read(backgroundSyncSchedulerProvider),
        offline: offline,
        manifest: manifest,
      );
    } catch (_) {
      // Best-effort — the next backgrounding gets another shot.
    }
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
    return Scaffold(
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
