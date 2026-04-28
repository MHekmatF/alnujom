import 'package:flutter/material.dart';

import 'tokens_stub.dart';

ThemeData appLightTheme() => _buildTheme(Brightness.light);

ThemeData appDarkTheme() => _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final primary = AppTokens.primary(brightness);
  final surface = AppTokens.surface(brightness);
  final onSurface = AppTokens.onSurface(brightness);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      surface: surface,
      onSurface: onSurface,
    ),
    scaffoldBackgroundColor: surface,
    textTheme: TextTheme(bodyMedium: AppTokens.bodyTextStyle(brightness)),
  );
}
