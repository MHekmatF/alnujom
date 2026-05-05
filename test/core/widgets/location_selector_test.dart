import 'package:alnujom/core/widgets/location_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
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
    'LocationSelector Row reverses under RTL — map_pin trails chevron, '
    'and the order flips back under LTR',
    (tester) async {
      await pumpWidgetKit(tester, const LocationSelector(city: 'Test'));
      final pinRtl = tester.getCenter(find.byIcon(LucideIcons.map_pin)).dx;
      final chevronRtl = tester
          .getCenter(find.byIcon(LucideIcons.chevron_down))
          .dx;
      // RTL: first child (map_pin) sits on the visual right
      expect(pinRtl, greaterThan(chevronRtl));

      await pumpWidgetKit(
        tester,
        const LocationSelector(city: 'Test'),
        direction: TextDirection.ltr,
      );
      final pinLtr = tester.getCenter(find.byIcon(LucideIcons.map_pin)).dx;
      final chevronLtr = tester
          .getCenter(find.byIcon(LucideIcons.chevron_down))
          .dx;
      // LTR: first child (map_pin) sits on the visual left
      expect(pinLtr, lessThan(chevronLtr));
    },
  );
}
