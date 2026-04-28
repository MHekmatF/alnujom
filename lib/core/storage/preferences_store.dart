import 'package:flutter/material.dart';

import '../errors/result.dart';

abstract interface class PreferencesStore {
  Future<Result<ThemeMode?>> readThemeMode();

  Future<Result<void>> writeThemeMode(ThemeMode mode);

  Future<Result<Locale?>> readLocale();

  Future<Result<void>> writeLocale(Locale locale);
}
