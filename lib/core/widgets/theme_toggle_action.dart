import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../localization/app_strings.dart';
import '../theme/theme_cubit.dart';

/// AppBar action that cycles the app theme mode: auto → light → dark → auto.
///
/// Mirrors [LocaleToggleAction] (single-tap AppBar affordance). The icon
/// reflects the *current* mode; the choice is persisted via [ThemeCubit].
class ThemeToggleAction extends StatelessWidget {
  const ThemeToggleAction({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.of(context).loc;
    final mode = context.watch<ThemeCubit>().state;

    final (IconData icon, AppThemeMode next) = switch (mode) {
      AppThemeMode.auto => (Icons.brightness_auto_outlined, AppThemeMode.light),
      AppThemeMode.light => (Icons.light_mode_outlined, AppThemeMode.dark),
      AppThemeMode.dark => (Icons.dark_mode_outlined, AppThemeMode.auto),
    };

    return IconButton(
      tooltip: l10n.themeToggleLabel,
      icon: Icon(icon),
      onPressed: () => unawaited(context.read<ThemeCubit>().setMode(next)),
    );
  }
}
