import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/di/injection.dart';
import 'core/flags/app_flags.dart';
import 'core/localization/locale_cubit.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/color_palette.dart';
import 'core/theme/palette_cubit.dart';
import 'core/theme/theme_cubit.dart';
import 'core/widgets/palette_tester.dart';
import 'l10n/app_localizations.dart';

class App extends StatelessWidget {
  const App({super.key, this.initialLocale = LocaleCubit.defaultLocale});

  final Locale initialLocale;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>(
          create: (_) => getIt<ThemeCubit>()..initialize(),
        ),
        BlocProvider<PaletteCubit>(
          create: (_) => getIt<PaletteCubit>()..initialize(),
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
              return BlocBuilder<PaletteCubit, ColorPalette>(
                builder: (context, palette) {
                  final router = getIt<GoRouter>();
                  return MaterialApp.router(
                    routerConfig: router,
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
                    themeAnimationDuration: const Duration(milliseconds: 240),
                    locale: locale,
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    debugShowCheckedModeBanner: false,
                    builder: (context, child) {
                      // Snapshot read of the current route — relies on the
                      // builder re-firing whenever the Navigator's child
                      // changes (which is what GoRouter does on navigation).
                      final currentPath =
                          router.routeInformationProvider.value.uri.path;
                      final showPaletteTester =
                          kDesignToolsEnabled &&
                          currentPath != '/_debug/theme-gallery';
                      return Stack(
                        children: [
                          child ?? const SizedBox.shrink(),
                          if (showPaletteTester) const PaletteTester(),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
