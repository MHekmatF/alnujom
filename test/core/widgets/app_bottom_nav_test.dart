import 'package:alnujom/core/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('AppBottomNav renders Arabic tabs and add callback', (
    tester,
  ) async {
    var addTapped = false;
    await pumpWidgetKit(
      tester,
      AppBottomNav(
        currentIndex: 0,
        onTabSelected: (_) {},
        onAddPressed: () => addTapped = true,
      ),
    );

    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('إضافة'), findsOneWidget);
    await tester.tap(find.text('إضافة'));
    expect(addTapped, isTrue);
  });

  // RTL/LTR matrix — T062
  testWidgets(
    'AppBottomNav tab order under RTL: الرئيسية (home) is rightmost, '
    'حسابي (profile) is leftmost',
    (tester) async {
      await pumpWidgetKit(
        tester,
        AppBottomNav(
          currentIndex: 0,
          onTabSelected: (_) {},
          onAddPressed: () {},
        ),
      );

      final homeX = tester.getCenter(find.text('الرئيسية')).dx;
      final profileX = tester.getCenter(find.text('حسابي')).dx;
      // under RTL Row reverses — first child (home) is on the right
      expect(homeX, greaterThan(profileX));
    },
  );

  testWidgets(
    'AppBottomNav tab order under LTR: الرئيسية (home) is leftmost, '
    'حسابي (profile) is rightmost',
    (tester) async {
      await pumpWidgetKit(
        tester,
        AppBottomNav(
          currentIndex: 0,
          onTabSelected: (_) {},
          onAddPressed: () {},
        ),
        direction: TextDirection.ltr,
      );

      final homeX = tester.getCenter(find.text('الرئيسية')).dx;
      final profileX = tester.getCenter(find.text('حسابي')).dx;
      // under LTR Row — first child (home) is on the left
      expect(homeX, lessThan(profileX));
    },
  );
}
