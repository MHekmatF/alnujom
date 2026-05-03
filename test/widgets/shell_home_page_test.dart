import 'package:alnujom/core/errors/result.dart';
import 'package:alnujom/core/localization/locale_cubit.dart';
import 'package:alnujom/core/logging/app_logger.dart';
import 'package:alnujom/core/storage/preferences_store.dart';
import 'package:alnujom/core/theme/color_palette.dart';
import 'package:alnujom/core/theme/theme_cubit.dart';
import 'package:alnujom/l10n/app_localizations.dart';
import 'package:alnujom/shell/shell_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the localized brand and toggles', (tester) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => ThemeCubit.test(
              store: _FakePreferencesStore(),
              log: _NoopLogger(),
            ),
          ),
          BlocProvider(
            create: (_) => LocaleCubit(
              _FakePreferencesStore(),
              _NoopLogger(),
              const Locale('ar'),
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ShellHomePage(),
        ),
      ),
    );

    final context = tester.element(find.byType(ShellHomePage));
    final l10n = AppLocalizations.of(context)!;

    expect(find.text(l10n.appTitle), findsOneWidget);
    expect(find.byKey(ShellHomePage.themeToggleKey), findsOneWidget);
    expect(find.byKey(ShellHomePage.localeToggleKey), findsOneWidget);
    expect(find.text(l10n.themeToggleLabel), findsOneWidget);
    expect(find.text(l10n.localeToggleLabel), findsOneWidget);
  });
}

final class _FakePreferencesStore implements PreferencesStore {
  @override
  Future<Result<AppThemeMode?>> readThemeMode() async => const Success(null);

  @override
  Future<Result<void>> writeThemeMode(AppThemeMode mode) async =>
      const Success(null);

  @override
  Future<Result<Locale?>> readLocale() async => const Success(null);

  @override
  Future<Result<void>> writeLocale(Locale locale) async => const Success(null);

  @override
  Future<Result<String?>> readPaletteName() async => const Success(null);

  @override
  Future<Result<void>> writePalette(ColorPalette palette) async =>
      const Success(null);
}

final class _NoopLogger implements AppLogger {
  @override
  void debug(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {}

  @override
  void info(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {}

  @override
  void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {}

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {}
}
