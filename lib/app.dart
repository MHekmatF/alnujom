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
import 'debug/palette_tester.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/notifications/presentation/widgets/notification_push_listener.dart';
import 'features/settings/presentation/bloc/app_settings_cubit.dart';
import 'l10n/app_localizations.dart';

class App extends StatefulWidget {
  const App({super.key, this.initialLocale = LocaleCubit.defaultLocale});

  final Locale initialLocale;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  // Phase 23 (FC / T025) — the singleton settings cubit. Fetched on app-start
  // (initState) and re-fetched on foreground-resume so the maintenance gate +
  // about surface react to admin changes (fetch-on-load + foreground-resume;
  // NOT Realtime — R-201). The same singleton instance is read synchronously
  // by the global redirect via getIt<AppSettingsCubit>().
  late final AppSettingsCubit _appSettingsCubit;

  @override
  void initState() {
    super.initState();
    _appSettingsCubit = getIt<AppSettingsCubit>();
    WidgetsBinding.instance.addObserver(this);
    // Initial load (fail-open on failure — never blocks app start).
    _appSettingsCubit.load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _appSettingsCubit.load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

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
          create: (_) => getIt<LocaleCubit>(param1: widget.initialLocale),
        ),
        BlocProvider<AuthBloc>.value(value: getIt<AuthBloc>()),
        BlocProvider<AppSettingsCubit>.value(value: _appSettingsCubit),
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
                      final currentPath =
                          router.routeInformationProvider.value.uri.path;
                      final showPaletteTester =
                          kDesignToolsEnabled &&
                          currentPath != '/_debug/theme-gallery';
                      // Phase 22 PN — wrap the app shell with the push listener
                      // so it is live app-wide (T036).  Inert when the no-op
                      // push adapter is bound (push unconfigured — FR-013).
                      return NotificationPushListener(
                        child: Stack(
                          children: [
                            child ?? const SizedBox.shrink(),
                            if (showPaletteTester) const PaletteTester(),
                          ],
                        ),
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
