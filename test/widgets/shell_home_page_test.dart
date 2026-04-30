import 'package:alnujom/core/errors/result.dart';
import 'package:alnujom/core/logging/app_logger.dart';
import 'package:alnujom/core/storage/preferences_store.dart';
import 'package:alnujom/core/theme/theme_cubit.dart';
import 'package:alnujom/l10n/app_localizations.dart';
import 'package:alnujom/shell/shell_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the localized brand and theme toggle', (tester) async {
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => ThemeCubit.test(
          preferencesStore: _FakePreferencesStore(),
          logger: _NoopLogger(),
          initialMode: ThemeMode.system,
          platformBrightness: Brightness.light,
        ),
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
    expect(find.text(l10n.themeToggleLabel), findsOneWidget);
  });
}

final class _FakePreferencesStore implements PreferencesStore {
  @override
  Future<Result<ThemeMode?>> readThemeMode() async => const Success(null);

  @override
  Future<Result<void>> writeThemeMode(ThemeMode mode) async =>
      const Success(null);

  @override
  Future<Result<Locale?>> readLocale() async => const Success(null);

  @override
  Future<Result<void>> writeLocale(Locale locale) async => const Success(null);
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
