import 'package:alnujom/core/errors/result.dart';
import 'package:alnujom/core/logging/app_logger.dart';
import 'package:alnujom/core/storage/preferences_store.dart';
import 'package:alnujom/core/theme/app_theme.dart';
import 'package:alnujom/core/theme/app_theme_mode.dart';
import 'package:alnujom/core/theme/color_palette.dart';
import 'package:alnujom/core/theme/palette_cubit.dart';
import 'package:alnujom/core/widgets/palette_tester.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PaletteTester cycles palette and shows snackbar', (
    tester,
  ) async {
    final store = _FakePreferencesStore();
    final cubit = PaletteCubit.test(
      store: store,
      log: _NoopLogger(),
      designToolsEnabled: true,
    );

    await tester.pumpWidget(_Harness(cubit: cubit));
    await tester.tap(find.byKey(PaletteTester.chipKey));
    await tester.pump();

    expect(cubit.state, isA<TrustPalette>());
    expect(store.writtenPaletteNames, ['trust']);
    expect(find.text('Trust'), findsWidgets);
  });
}

class _Harness extends StatelessWidget {
  const _Harness({required this.cubit});

  final PaletteCubit cubit;

  @override
  Widget build(BuildContext context) {
    const locale = Locale('ar');
    return BlocProvider.value(
      value: cubit,
      child: MaterialApp(
        locale: locale,
        theme: buildAppTheme(
          palette: const ModernPalette(),
          brightness: Brightness.light,
          locale: locale,
        ),
        home: const Scaffold(
          body: Stack(children: [PaletteTester(designToolsEnabled: true)]),
        ),
      ),
    );
  }
}

final class _FakePreferencesStore implements PreferencesStore {
  final writtenPaletteNames = <String>[];

  @override
  Future<Result<String?>> readPaletteName() async => const Success(null);

  @override
  Future<Result<void>> writePalette(ColorPalette palette) async {
    writtenPaletteNames.add(palette.name);
    return const Success(null);
  }

  @override
  Future<Result<AppThemeMode?>> readThemeMode() async => const Success(null);

  @override
  Future<Result<void>> writeThemeMode(AppThemeMode mode) async =>
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
