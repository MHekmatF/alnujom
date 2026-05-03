import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/di/injection.dart';
import 'core/localization/locale_cubit.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/color_palette.dart';
import 'core/theme/theme_cubit.dart';
import 'l10n/app_localizations.dart';

class App extends StatelessWidget {
  const App({
    super.key,
    this.initialLocale = LocaleCubit.defaultLocale,
  });

  final Locale initialLocale;

  @override
  Widget build(BuildContext context) {
    const palette = ColorPalette.defaultPalette;

    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>(
          create: (_) => getIt<ThemeCubit>()..initialize(),
        ),
        BlocProvider<LocaleCubit>(
          create: (_) => getIt<LocaleCubit>(param1: initialLocale),
        ),
      ],
      child: BlocBuilder<ThemeCubit, AppThemeMode>(
        builder: (context, appThemeMode) {
          final themeMode = switch (appThemeMode) {
            AppThemeMode.auto => ThemeMode.system,
            AppThemeMode.light => ThemeMode.light,
            AppThemeMode.dark => ThemeMode.dark,
          };
          return BlocBuilder<LocaleCubit, Locale>(
            builder: (context, locale) {
              return MaterialApp.router(
                routerConfig: getIt<GoRouter>(),
                theme: buildAppTheme(
                  palette: palette,
                  brightness: Brightness.light,
                  locale: locale,
                ),
                darkTheme: buildAppTheme(
                  palette: palette,
                  brightness: Brightness.dark,
                  locale: locale,
                ),
                themeMode: themeMode,
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                debugShowCheckedModeBanner: false,
              );
            },
          );
        },
      ),
    );
  }
}
