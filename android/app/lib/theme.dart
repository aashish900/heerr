import 'package:flutter/material.dart';

import 'widgets/gradient_tab_indicator.dart';

const Color heerrMagenta = Color(0xFFF533C8);
const Color heerrPurple = Color(0xFFA93CF2);
const Color heerrViolet = Color(0xFF6F4BF5);
const Color heerrBlack = Color(0xFF0A0A0A);

const LinearGradient heerrGradient = LinearGradient(
  colors: <Color>[heerrMagenta, heerrPurple, heerrViolet],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

ThemeData heerrDarkTheme() {
  const ColorScheme cs = ColorScheme(
    brightness: Brightness.dark,
    primary: heerrMagenta,
    onPrimary: Colors.black,
    secondary: heerrPurple,
    onSecondary: Colors.black,
    tertiary: heerrViolet,
    onTertiary: Colors.white,
    error: Color(0xFFCF6679),
    onError: Colors.black,
    surface: heerrBlack,
    onSurface: Colors.white,
    // Neutral dark-grey elevation ladder (darkest → lightest). Explicit so
    // the near-black theme doesn't fall back to M3's purple-tinted defaults;
    // grid tiles / cards (High) and the search pill (Highest) read as flat
    // neutral greys, matching the redesign reference.
    surfaceContainerLowest: Color(0xFF0D0D0D),
    surfaceContainerLow: Color(0xFF121212),
    surfaceContainer: Color(0xFF161616),
    surfaceContainerHigh: Color(0xFF1C1C1C),
    surfaceContainerHighest: Color(0xFF222222),
    onSurfaceVariant: Color(0xFFB0B0B0),
    outline: Color(0xFF2E2E2E),
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
          return const IconThemeData(color: heerrMagenta);
        }
        return const IconThemeData(color: Color(0xFF606060));
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(color: heerrMagenta, fontWeight: FontWeight.w600);
        }
        return const TextStyle(color: Color(0xFF606060));
      }),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return heerrMagenta;
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.black;
          return const Color(0xFFB0B0B0);
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const BorderSide(color: heerrMagenta);
          }
          return const BorderSide(color: Color(0xFF2E2E2E));
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
      color: Color(0xFF141414),
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF2E2E2E),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Color(0xFFB0B0B0),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: heerrMagenta,
      thumbColor: heerrMagenta,
      inactiveTrackColor: Color(0xFF2E2E2E),
      overlayColor: Color(0x29F533C8),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: heerrMagenta,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: heerrMagenta,
      unselectedLabelColor: Color(0xFF808080),
      indicator: GradientTabIndicator(),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF1A1A1A),
      selectedColor: heerrMagenta.withValues(alpha: 0.2),
      labelStyle: const TextStyle(color: Colors.white),
      side: const BorderSide(color: Color(0xFF2E2E2E)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return heerrMagenta;
        return const Color(0xFF606060);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return heerrMagenta.withValues(alpha: 0.4);
        }
        return const Color(0xFF2E2E2E);
      }),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: heerrMagenta,
      foregroundColor: Colors.black,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: heerrMagenta),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: heerrMagenta,
        foregroundColor: Colors.black,
      ),
    ),
  );
}
