import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'theme.dart';

void main() {
  runApp(const ProviderScope(child: HeerrApp()));
}

class HeerrApp extends StatelessWidget {
  const HeerrApp({super.key});

  @override
  Widget build(BuildContext context) {
    final GoRouter router = buildHeerrRouter();
    return MaterialApp.router(
      title: 'heerr',
      debugShowCheckedModeBanner: false,
      theme: heerrDarkTheme(),
      routerConfig: router,
    );
  }
}
