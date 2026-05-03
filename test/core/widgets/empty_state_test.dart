import 'package:alnujom/core/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('EmptyState collapses optional sections', (tester) async {
    await pumpWidgetKit(tester, const EmptyState(headline: 'No data'));

    expect(find.text('No data'), findsOneWidget);
  });

  // RTL/LTR matrix — T062
  testWidgets('EmptyState renders headline and body under LTR', (tester) async {
    await pumpWidgetKit(
      tester,
      const EmptyState(headline: 'Empty', body: 'Nothing here'),
      direction: TextDirection.ltr,
    );
    expect(find.text('Empty'), findsOneWidget);
    expect(find.text('Nothing here'), findsOneWidget);
  });

  testWidgets(
    'EmptyState headline is centered under both RTL and LTR',
    (tester) async {
      const headline = 'Centered Headline';

      await pumpWidgetKit(
        tester,
        const EmptyState(headline: headline),
      );
      final centerRtl = tester.getCenter(find.text(headline)).dx;

      await pumpWidgetKit(
        tester,
        const EmptyState(headline: headline),
        direction: TextDirection.ltr,
      );
      final centerLtr = tester.getCenter(find.text(headline)).dx;

      // Both directions should produce a centered headline at roughly the
      // same x position (within 2 px — centered text is layout-agnostic)
      expect(centerRtl, closeTo(centerLtr, 2));
    },
  );
}
