import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: HeerrApp()));
}

class HeerrApp extends StatelessWidget {
  const HeerrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'heerr',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1DB954),
          brightness: Brightness.dark,
        ),
      ),
      home: const Scaffold(
        body: Center(
          child: Text(
            'heerr',
            style: TextStyle(fontSize: 48, fontWeight: FontWeight.w300),
          ),
        ),
      ),
    );
  }
}
