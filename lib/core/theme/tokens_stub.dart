import 'package:flutter/material.dart';

abstract final class AppTokens {
  static Color primary(Brightness brightness) => switch (brightness) {
    Brightness.light => const Color(0xFF2457A6),
    Brightness.dark => const Color(0xFF9FC5FF),
  };

  static Color surface(Brightness brightness) => switch (brightness) {
    Brightness.light => const Color(0xFFF8FAFF),
    Brightness.dark => const Color(0xFF101722),
  };

  static Color onSurface(Brightness brightness) => switch (brightness) {
    Brightness.light => const Color(0xFF152033),
    Brightness.dark => const Color(0xFFE8EEF9),
  };

  static TextStyle bodyTextStyle(Brightness brightness) =>
      TextStyle(color: onSurface(brightness), fontSize: 16, height: 1.4);
}
