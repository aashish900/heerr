import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/job_detail_screen.dart';
import 'screens/queue_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';

// Route paths — kept as constants so widget tests and link callers don't
// drift apart. Settings is exposed via `/settings`; routing redirects to
// it when the bearer token is missing (wired at B1/B3 — not here).
class Routes {
  static const String search = '/';
  static const String queue = '/queue';
  static const String settings = '/settings';

  // Job-detail lands at D3; route shape defined here to lock the URL.
  static String job(String id) => '/job/$id';
}

/// Builds the app's `GoRouter`. Lives at module scope so widget tests can
/// reuse the exact router config the app boots with.
GoRouter buildHeerrRouter() {
  return GoRouter(
    initialLocation: Routes.search,
    routes: <RouteBase>[
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return _ShellScaffold(location: state.matchedLocation, child: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: Routes.search,
            builder: (BuildContext context, GoRouterState state) =>
                const SearchScreen(),
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
    ],
  );
}

// Bottom-nav shell. Wraps every child route with the same `NavigationBar`
// so tab switches don't tear down state inside the surrounding scaffold.
class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold({required this.location, required this.child});

  final String location;
  final Widget child;

  static const List<_NavTab> _tabs = <_NavTab>[
    _NavTab(
      path: Routes.search,
      label: 'Search',
      icon: Icons.search_outlined,
      selectedIcon: Icons.search,
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
    for (int i = 0; i < _tabs.length; i++) {
      if (loc == _tabs[i].path) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final int currentIndex = _indexFor(location);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
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
