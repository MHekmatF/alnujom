import 'package:alnujom/core/theme/color_palette.dart';
import 'package:alnujom/debug/theme_gallery_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cases = [
    _GalleryCase(Brightness.light, Locale('ar')),
    _GalleryCase(Brightness.light, Locale('en')),
    _GalleryCase(Brightness.dark, Locale('ar')),
    _GalleryCase(Brightness.dark, Locale('en')),
  ];

  for (final testCase in cases) {
    testWidgets(
      'ThemeGallery renders ${testCase.brightness.name} ${testCase.locale.languageCode}',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ThemeGalleryPage(
              initialBrightness: testCase.brightness,
              initialLocale: testCase.locale,
              initialPalette: const ModernPalette(),
            ),
          ),
        );
        // pump() not pumpAndSettle(): the gallery contains LoadingState.card()
        // whose shimmer loops indefinitely and would hang pumpAndSettle.
        await tester.pump();

        expect(tester.takeException(), isNull);
        for (final header in ThemeGalleryPage.sectionHeadersFor(
          testCase.locale,
        )) {
          expect(find.text(header), findsAtLeastNWidgets(1));
        }
        expect(
          find.byKey(const ValueKey<String>('theme-gallery-locale-switcher')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('theme-gallery-theme-switcher')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('theme-gallery-palette-switcher')),
          findsOneWidget,
        );

        await tester.tap(find.text('Trust'));
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
}

final class _GalleryCase {
  const _GalleryCase(this.brightness, this.locale);

  final Brightness brightness;
  final Locale locale;
}
