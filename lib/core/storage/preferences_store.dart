import 'package:flutter/material.dart';

import '../errors/result.dart';
import '../theme/app_theme_mode.dart';

abstract interface class PreferencesStore {
  Future<Result<AppThemeMode?>> readThemeMode();

  Future<Result<void>> writeThemeMode(AppThemeMode mode);

  Future<Result<Locale?>> readLocale();

  Future<Result<void>> writeLocale(Locale locale);
}
