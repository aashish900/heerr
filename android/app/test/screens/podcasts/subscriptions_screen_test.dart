import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:heerr/models/podcast_channel.dart';
import 'package:heerr/screens/podcasts/subscriptions_screen.dart';
import 'package:heerr/services/backend_service.dart';

class _StubBackend extends BackendService {
  _StubBackend(this._subscriptions) : super(Dio());
  final List<PodcastChannel> _subscriptions;

  @override
  Future<List<PodcastChannel>> podcastSubscriptions() async =>
      _subscriptions;
}

Widget _wrap({required BackendService backend}) {
  final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => const SubscriptionsScreen(),
      ),
      GoRoute(
        path: '/podcasts/discover',
        builder: (_, _) => const Scaffold(body: Text('DISCOVER_SCREEN')),
      ),
      GoRoute(
        path: '/podcasts/channel/:id',
        builder: (BuildContext context, GoRouterState state) => Scaffold(
          body: Text('CHANNEL_SCREEN_${state.pathParameters['id']}'),
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: <Override>[
      backendServiceProvider.overrideWith((_) async => backend),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('renders an empty state with a Discover CTA when unsubscribed',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(backend: _StubBackend(const <PodcastChannel>[])));
    await tester.pumpAndSettle();

    expect(find.text('No subscriptions yet'), findsOneWidget);
    expect(find.text('Discover podcasts'), findsOneWidget);
  });

  testWidgets('renders one card per subscribed channel',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      backend: _StubBackend(const <PodcastChannel>[
        PodcastChannel(id: 'c1', feedUrl: 'https://a.com/f.xml', title: 'Show A'),
        PodcastChannel(id: 'c2', feedUrl: 'https://b.com/f.xml', title: 'Show B'),
      ]),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Show A'), findsOneWidget);
    expect(find.text('Show B'), findsOneWidget);
  });

  testWidgets('tapping the add icon pushes Discover',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(backend: _StubBackend(const <PodcastChannel>[])));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('podcasts-discover-action')));
    await tester.pumpAndSettle();

    expect(find.text('DISCOVER_SCREEN'), findsOneWidget);
  });

  testWidgets('tapping a channel card pushes its channel screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      backend: _StubBackend(const <PodcastChannel>[
        PodcastChannel(id: 'c1', feedUrl: 'https://a.com/f.xml', title: 'Show A'),
      ]),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('podcast-subscription-c1')));
    await tester.pumpAndSettle();

    expect(find.text('CHANNEL_SCREEN_c1'), findsOneWidget);
  });
}
