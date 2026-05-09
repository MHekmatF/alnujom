import 'dart:ui' show Locale;

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show ThemeMode;

class UserPreferences extends Equatable {
  const UserPreferences({
    required this.userId,
    required this.locale,
    required this.themeMode,
    required this.displayCurrency,
    required this.notificationsEnabled,
  });

  final String userId;
  final Locale locale;
  final ThemeMode themeMode;
  final String displayCurrency;
  final bool notificationsEnabled;

  UserPreferences copyWith({
    String? userId,
    Locale? locale,
    ThemeMode? themeMode,
    String? displayCurrency,
    bool? notificationsEnabled,
  }) => UserPreferences(
    userId: userId ?? this.userId,
    locale: locale ?? this.locale,
    themeMode: themeMode ?? this.themeMode,
    displayCurrency: displayCurrency ?? this.displayCurrency,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
  );

  @override
  List<Object?> get props => [
    userId,
    locale,
    themeMode,
    displayCurrency,
    notificationsEnabled,
  ];
}
