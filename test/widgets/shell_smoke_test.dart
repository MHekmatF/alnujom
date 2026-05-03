import 'package:alnujom/app.dart';
import 'package:alnujom/core/di/injection.dart';
import 'package:alnujom/core/errors/result.dart';
import 'package:alnujom/core/storage/preferences_store.dart';
import 'package:alnujom/core/theme/app_theme_mode.dart';
import 'package:alnujom/l10n/app_localizations.dart';
import 'package:alnujom/shell/shell_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  setUpAll(() async {
    if (!getIt.isRegistered<GoRouter>()) {
      await configureDependencies();
    }
    getIt.allowReassignment = true;
    getIt.registerSingleton<PreferencesStore>(_FakePreferencesStore());
  });

  testWidgets('boots the app shell and toggles theme and locale', (
    tester,
  ) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ShellHomePage));
    final l10n = AppLocalizations.of(context)!;

    expect(find.text(l10n.appTitle), findsOneWidget);
    expect(Directionality.of(context), TextDirection.rtl);

    // Cycle: auto → light (1st tap), light → dark (2nd tap)
    // Two taps are needed to reach dark from the default auto state.
    await tester.tap(find.byKey(ShellHomePage.themeToggleKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ShellHomePage.themeToggleKey));
    await tester.pumpAndSettle();

    final darkContext = tester.element(find.byType(ShellHomePage));
    expect(Theme.of(darkContext).brightness, Brightness.dark);

    await tester.tap(find.byKey(ShellHomePage.localeToggleKey));
    await tester.pumpAndSettle();

    final englishContext = tester.element(find.byType(ShellHomePage));
    expect(Directionality.of(englishContext), TextDirection.ltr);

    await tester.tap(find.byKey(ShellHomePage.localeToggleKey));
    await tester.pumpAndSettle();

    final arabicContext = tester.element(find.byType(ShellHomePage));
    expect(Directionality.of(arabicContext), TextDirection.rtl);
    expect(tester.takeException(), isNull);
  });
}

final class _FakePreferencesStore implements PreferencesStore {
  AppThemeMode? themeMode;
  Locale? locale;

  @override
  Future<Result<AppThemeMode?>> readThemeMode() async => Success(themeMode);

  @override
  Future<Result<void>> writeThemeMode(AppThemeMode mode) async {
    themeMode = mode;
    return const Success(null);
  }

  @override
  Future<Result<Locale?>> readLocale() async => Success(locale);

  @override
  Future<Result<void>> writeLocale(Locale locale) async {
    this.locale = locale;
    return const Success(null);
  }
}
