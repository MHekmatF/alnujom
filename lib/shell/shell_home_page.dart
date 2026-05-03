import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/localization/locale_cubit.dart';
import '../core/theme/colors.dart';
import '../core/theme/spacing.dart';
import '../core/theme/theme_cubit.dart';
import '../core/theme/typography.dart';
import '../l10n/app_localizations.dart';

class ShellHomePage extends StatelessWidget {
  const ShellHomePage({super.key});

  static const themeToggleKey = Key('shell.themeToggle');
  static const localeToggleKey = Key('shell.localeToggle');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);
    final textStyles = AppTextStyles.of(context);
    final themeMode = context.watch<ThemeCubit>().state;
    final locale = context.watch<LocaleCubit>().state;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.appTitle,
                style: textStyles.headlineMedium.copyWith(
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    label: l10n.themeToggleLabel,
                    value: '${l10n.currentTheme}: ${themeMode.name}',
                    button: true,
                    child: OutlinedButton.icon(
                      key: themeToggleKey,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () {
                        unawaited(context.read<ThemeCubit>().toggle());
                      },
                      icon: Icon(_themeIcon(themeMode)),
                      label: Text(l10n.themeToggleLabel),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Semantics(
                    label: l10n.localeToggleLabel,
                    value: '${l10n.currentLocale}: ${locale.languageCode}',
                    button: true,
                    child: OutlinedButton.icon(
                      key: localeToggleKey,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () {
                        unawaited(context.read<LocaleCubit>().toggle());
                      },
                      icon: const Icon(Icons.language_outlined),
                      label: Text(l10n.localeToggleLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _themeIcon(ThemeMode themeMode) => switch (themeMode) {
    ThemeMode.dark => Icons.dark_mode_outlined,
    ThemeMode.light => Icons.light_mode_outlined,
    ThemeMode.system => Icons.brightness_auto_outlined,
  };
}
