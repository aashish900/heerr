import 'package:flutter/material.dart';

// Spotify-influenced accent. Locked in docs/DECISIONLOG.md
// 2026-06-09 "Theme: Material 3, dark only, seed #1DB954".
const Color _heerrSeed = Color(0xFF1DB954);

ThemeData heerrDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _heerrSeed,
      brightness: Brightness.dark,
    ),
  );
}
