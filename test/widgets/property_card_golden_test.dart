import 'package:alnujom/core/theme/app_theme.dart';
import 'package:alnujom/core/theme/color_palette.dart';
import 'package:alnujom/core/widgets/property_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cases = [
    _GoldenCase('light_ar', Brightness.light, Locale('ar'), TextDirection.rtl),
    _GoldenCase('light_en', Brightness.light, Locale('en'), TextDirection.ltr),
    _GoldenCase('dark_ar', Brightness.dark, Locale('ar'), TextDirection.rtl),
    _GoldenCase('dark_en', Brightness.dark, Locale('en'), TextDirection.ltr),
  ];

  for (final testCase in cases) {
    testWidgets('PropertyCard golden ${testCase.name}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _GoldenHarness(
          brightness: testCase.brightness,
          locale: testCase.locale,
          direction: testCase.direction,
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(_GoldenHarness.boundaryKey),
        matchesGoldenFile('../goldens/property_card/${testCase.name}.png'),
      );
    });
  }
}

class _GoldenHarness extends StatelessWidget {
  const _GoldenHarness({
    required this.brightness,
    required this.locale,
    required this.direction,
  });

  static const boundaryKey = ValueKey<String>('property-card-golden-boundary');

  final Brightness brightness;
  final Locale locale;
  final TextDirection direction;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: locale,
      theme: buildAppTheme(
        palette: const ModernPalette(),
        brightness: brightness,
        locale: locale,
      ),
      home: Directionality(
        textDirection: direction,
        child: const Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: PropertyCard(
                title: 'Modern family apartment near services',
                price: '250,000,000',
                currency: 'ل.س',
                location: 'Damascus / Malki',
                featured: true,
                favorite: true,
                // Pass a no-op so the favorite IconButton renders; without
                // this, the new conditional in PropertyCard hides the heart.
                onFavoritePressed: _noop,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _GoldenCase {
  const _GoldenCase(this.name, this.brightness, this.locale, this.direction);

  final String name;
  final Brightness brightness;
  final Locale locale;
  final TextDirection direction;
}

void _noop() {}
