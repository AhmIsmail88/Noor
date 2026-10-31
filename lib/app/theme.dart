import 'package:flutter/material.dart';

/// Palette taken from the app icon: deep violet background, lavender crescent.
class NoorColors {
  static const background = Color(0xFF110A24);
  static const surface = Color(0xFF1A0F33);
  static const surfaceHigh = Color(0xFF2D1F52);
  static const violet = Color(0xFF9B6BFF);
  static const lavender = Color(0xFFEADDFF);
  static const lavenderSoft = Color(0xFFB794FF);
}

ThemeData darkTheme() {
  const scheme = ColorScheme.dark(
    primary: NoorColors.lavenderSoft,
    onPrimary: Color(0xFF2A0E5E),
    primaryContainer: Color(0xFF4A2A8F),
    onPrimaryContainer: NoorColors.lavender,
    secondary: Color(0xFFCDB8F5),
    onSecondary: Color(0xFF2A0E5E),
    secondaryContainer: Color(0xFF3B2A63),
    onSecondaryContainer: NoorColors.lavender,
    surface: NoorColors.surface,
    onSurface: Color(0xFFEDE6FA),
    onSurfaceVariant: Color(0xFFB9ABD6),
    outline: Color(0xFF7E6CA8),
    surfaceContainerHighest: NoorColors.surfaceHigh,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Cairo',
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: NoorColors.background,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: NoorColors.surface,
      indicatorColor: scheme.primaryContainer,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: NoorColors.surface,
      indicatorColor: scheme.primaryContainer,
    ),
  );
}

ThemeData lightTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Cairo',
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C4DFF)),
);
