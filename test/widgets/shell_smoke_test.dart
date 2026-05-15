import 'package:alnujom/app.dart';
import 'package:alnujom/core/di/injection.dart';
import 'package:alnujom/core/errors/result.dart';
import 'package:alnujom/core/storage/preferences_store.dart';
import 'package:alnujom/core/theme/app_theme_mode.dart';
import 'package:alnujom/core/theme/color_palette.dart';
import 'package:alnujom/l10n/app_localizations.dart';
import 'package:alnujom/shell/shell_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
void main() {
  // Test body is `skip: true` (see D-05 in specs/005-auth-profile/DEFERRED.md).
  // setUpAll is intentionally minimal — when the test is restored, it will
  // need to:
  //   1. Mock SharedPreferences via SharedPreferences.setMockInitialValues({})
  //   2. Call Supabase.initialize with stub credentials (the App eagerly
  //      constructs AuthBloc → AuthRepository → SupabaseAuthDataSource)
  //   3. Register a fake PreferencesStore
  // OR refactor to build ShellHomePage directly with cubit providers,
  // bypassing the full App tree (preferred — see DEFERRED.md D-05).
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
    // SKIP reason: Phase 2 shell-demo test. Spec/005 changed App routing to
    // /splash + auth-driven; the AuthRedirect sends unauthenticated users to
    // /login (since '/' is not in _authOnlyPaths or _publicPaths), so
    // ShellHomePage at '/' is unreachable via the full App widget tree.
    // Restore by rewriting the test to build ShellHomePage directly with the
    // cubit providers rather than pumping the full App. Tracked alongside
    // spec/005 DEFERRED.md.
  }, skip: true);
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

  @override
  Future<Result<String?>> readPaletteName() async => const Success(null);

  @override
  Future<Result<void>> writePalette(ColorPalette palette) async =>
      const Success(null);
}
