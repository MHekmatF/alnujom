import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/di/injection.dart';
import 'core/flags/app_flags.dart';
import 'core/localization/locale_cubit.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/color_palette.dart';
import 'core/theme/palette_cubit.dart';
import 'core/theme/theme_cubit.dart';
import 'debug/palette_tester.dart';
import 'features/app_update/presentation/bloc/app_update_cubit.dart';
import 'features/app_update/presentation/widgets/update_prompt_dialog.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/widgets/password_recovery_listener.dart';
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

  // Phase 24 UP (T018) — the singleton update-check cubit. [check] is called
  // ONCE on cold start (NOT on resume — R-211). The dialog is shown once per
  // session on [UpdateAvailable]; no persisted dismissed-version state.
  late final AppUpdateCubit _appUpdateCubit;

  @override
  void initState() {
    super.initState();
    _appSettingsCubit = getIt<AppSettingsCubit>();
    _appUpdateCubit = getIt<AppUpdateCubit>();
    WidgetsBinding.instance.addObserver(this);
    // Initial load (fail-open on failure — never blocks app start).
    _appSettingsCubit.load();
    // Cold-start update check — fail-silent (FR-010); dialog shown from the
    // BlocListener in [build] when [UpdateAvailable] is emitted.
    _appUpdateCubit.check();
    // Phase 24 (CR / T007) — QA-only forced-crash affordance, gated by the
    // `SENTRY_TEST_CRASH` dart-define. INERT in the shipped release (the flag
    // defaults false and is never set in a release build). Throws an uncaught
    // async error so the runZonedGuarded / PlatformDispatcher.onError path
    // routes it to CrashReporter.recordError — used to verify (a) a forced
    // crash reaches the Sentry dashboard and (b) an unreachable DSN never
    // blocks or crashes the app (FR-007).
    if (const bool.fromEnvironment('SENTRY_TEST_CRASH')) {
      Future<void>.delayed(const Duration(seconds: 3), () {
        throw StateError('SENTRY_TEST_CRASH — forced test exception (CR/T007)');
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Settings are re-fetched on every resume (Phase 23 — maintenance gate).
      // Update check is NOT re-triggered here (cold-start only — R-211).
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
        // Phase 24 UP — provide the update cubit app-wide so the listener
        // below can react to UpdateAvailable.
        BlocProvider<AppUpdateCubit>.value(value: _appUpdateCubit),
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
                      //
                      // Phase 24 UP — BlocListener shows the update prompt
                      // exactly once per cold start when UpdateAvailable is
                      // emitted (session-once; no persisted state — R-211).
                      return BlocListener<AppUpdateCubit, AppUpdateState>(
                        listenWhen: (_, current) =>
                            current.status == AppUpdateStatus.updateAvailable &&
                            current.manifest != null,
                        listener: (listenerContext, state) {
                          // NOTE: `listenerContext` here is the MaterialApp.router
                          // `builder` context, which sits ABOVE the GoRouter
                          // Navigator — showDialog with it finds no Navigator and
                          // silently fails. Use the root navigator context so the
                          // dialog attaches correctly (Phase 24 UP live-QA fix).
                          final navContext = rootNavigatorKey.currentContext;
                          if (navContext != null) {
                            showUpdatePrompt(navContext, state.manifest!);
                          }
                        },
                        child: NotificationPushListener(
                          // Spec 005 D-01 — routes to the "set a new password"
                          // screen when a recovery deep link is exchanged for
                          // a session (warm resume AND cold launch; the
                          // repository replays a recovery that landed before
                          // this widget mounted).
                          child: PasswordRecoveryListener(
                            child: Stack(
                              children: [
                                child ?? const SizedBox.shrink(),
                                if (showPaletteTester) const PaletteTester(),
                              ],
                            ),
                          ),
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
