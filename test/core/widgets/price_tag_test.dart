import 'package:alnujom/core/widgets/price_tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('PriceTag renders amount and alternate text', (tester) async {
    await pumpWidgetKit(
      tester,
      const PriceTag(amount: '100', currency: 'USD', altText: '1,000,000 ل.س'),
    );

    expect(find.text('100 USD'), findsOneWidget);
    expect(find.text('1,000,000 ل.س'), findsOneWidget);
  });

  // RTL/LTR matrix — T062
  testWidgets(
    'PriceTag price text carries explicit TextDirection.ltr — renders '
    'correctly under RTL UI direction',
    (tester) async {
      await pumpWidgetKit(
        tester,
        const PriceTag(amount: '250', currency: 'USD'),
      );
      // Explicit textDirection: TextDirection.ltr on price text keeps number
      // formatting LTR even inside the RTL widget tree.
      expect(find.text('250 USD'), findsOneWidget);
    },
  );

  testWidgets('PriceTag renders without error under LTR', (tester) async {
    await pumpWidgetKit(
      tester,
      const PriceTag(amount: '250', currency: 'USD'),
      direction: TextDirection.ltr,
    );
    expect(find.text('250 USD'), findsOneWidget);
  });
}
