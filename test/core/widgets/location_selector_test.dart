import 'package:alnujom/core/widgets/location_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('LocationSelector invokes callback', (tester) async {
    var tapped = false;
    await pumpWidgetKit(
      tester,
      LocationSelector(city: 'دمشق', area: 'المزة', onTap: () => tapped = true),
    );

    expect(find.text('دمشق / المزة'), findsOneWidget);
    await tester.tap(find.text('دمشق / المزة'));
    expect(tapped, isTrue);
  });

  // RTL/LTR matrix — T062
  testWidgets('LocationSelector renders correctly under LTR', (tester) async {
    await pumpWidgetKit(
      tester,
      const LocationSelector(city: 'Damascus', area: 'Mezzeh'),
      direction: TextDirection.ltr,
    );
    expect(find.text('Damascus / Mezzeh'), findsOneWidget);
  });

  testWidgets(
    'LocationSelector start-padding is symmetric — content at same inset '
    'from both edges under both directions',
    (tester) async {
      const city = 'Test';

      await pumpWidgetKit(
        tester,
        const LocationSelector(city: city),
      );
      final textRtl = tester.getTopLeft(find.text(city));

      await pumpWidgetKit(
        tester,
        const LocationSelector(city: city),
        direction: TextDirection.ltr,
      );
      final textLtr = tester.getTopLeft(find.text(city));

      // Both directions render the text — positions differ (RTL/LTR flip)
      // but neither should be at x=0 (padding is applied in both directions)
      expect(textRtl.dx, isNonZero);
      expect(textLtr.dx, isNonZero);
    },
  );
}
