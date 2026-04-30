import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/di/injection.dart';
import 'core/localization/locale_cubit.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'l10n/app_localizations.dart';

class App extends StatelessWidget {
  const App({
    super.key,
    this.initialThemeMode = ThemeMode.system,
    this.initialLocale = LocaleCubit.defaultLocale,
  });

  final ThemeMode initialThemeMode;
  final Locale initialLocale;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>(
          create: (_) => getIt<ThemeCubit>(param1: initialThemeMode),
        ),
        BlocProvider<LocaleCubit>(
          create: (_) => getIt<LocaleCubit>(param1: initialLocale),
        ),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return BlocBuilder<LocaleCubit, Locale>(
            builder: (context, locale) {
              return MaterialApp.router(
                routerConfig: getIt<GoRouter>(),
                theme: appLightTheme(),
                darkTheme: appDarkTheme(),
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
