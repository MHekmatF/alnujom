import 'package:alnujom/core/widgets/app_bottom_nav.dart';
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
}
