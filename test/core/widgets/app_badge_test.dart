import 'package:alnujom/core/widgets/app_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('AppBadge pairs every variant with both icon and label', (
    tester,
  ) async {
    for (final variant in AppBadgeVariant.values) {
      await pumpWidgetKit(
        tester,
        AppBadge(label: variant.name, variant: variant),
      );

      final badge = find.byType(AppBadge);
      expect(badge, findsOneWidget, reason: 'badge missing for $variant');
      expect(
        find.descendant(of: badge, matching: find.byType(Icon)),
        findsOneWidget,
        reason: 'FR-012: $variant must pair color with an icon',
      );
      expect(
        find.descendant(of: badge, matching: find.text(variant.name)),
        findsOneWidget,
        reason: 'FR-012: $variant must pair color with a label',
      );
    }
  });
}
