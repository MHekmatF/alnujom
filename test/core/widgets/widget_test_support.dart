import 'package:alnujom/core/theme/app_theme.dart';
import 'package:alnujom/core/theme/color_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpWidgetKit(
  WidgetTester tester,
  Widget child, {
  TextDirection direction = TextDirection.rtl,
}) {
  final locale = direction == TextDirection.rtl
      ? const Locale('ar')
      : const Locale('en');
  return tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: buildAppTheme(
        palette: const ModernPalette(),
        brightness: Brightness.light,
        locale: locale,
      ),
      home: Directionality(
        textDirection: direction,
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}
