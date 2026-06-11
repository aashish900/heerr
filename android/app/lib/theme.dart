import 'package:flutter/material.dart';

const Color heerrGreen = Color(0xFF1DB954);
const Color heerrBlack = Color(0xFF000000);
const Color heerrGolden = Color(0xFFD4A857);

ThemeData heerrDarkTheme() {
  const ColorScheme cs = ColorScheme(
    brightness: Brightness.dark,
    primary: heerrGreen,
    onPrimary: heerrBlack,
    secondary: heerrGreen,
    onSecondary: heerrBlack,
    tertiary: heerrGreen,
    onTertiary: heerrBlack,
    error: Color(0xFFCF6679),
    onError: heerrBlack,
    surface: heerrBlack,
    onSurface: Colors.white,
    surfaceContainerHighest: Color(0xFF1A1A1A),
    onSurfaceVariant: Color(0xFFB0B0B0),
    outline: Color(0xFF3A3A3A),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: heerrBlack,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      height: 80,
      indicatorColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: heerrGreen);
        }
        return const IconThemeData(color: Color(0xFF808080));
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(color: heerrGreen, fontWeight: FontWeight.w600);
        }
        return const TextStyle(color: Color(0xFF808080));
      }),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return heerrGreen;
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return heerrBlack;
          return Colors.white;
        }),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: heerrBlack,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: const CardThemeData(
      color: Color(0xFF111111),
      surfaceTintColor: Colors.transparent,
    ),
  );
}
