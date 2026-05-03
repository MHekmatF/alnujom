import 'package:alnujom/core/widgets/app_tabs.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('AppTabs segmented emits selection', (tester) async {
    var selected = 0;
    await pumpWidgetKit(
      tester,
      AppTabs(
        labels: const ['A', 'B'],
        selectedIndex: selected,
        onChanged: (next) => selected = next,
      ),
    );

    await tester.tap(find.text('B'));
    expect(selected, 1);
  });

  testWidgets('AppTabs underline variant emits selection on tap', (
    tester,
  ) async {
    var selected = 0;
    await pumpWidgetKit(
      tester,
      AppTabs(
        labels: const ['One', 'Two', 'Three', 'Four'],
        selectedIndex: selected,
        variant: AppTabsVariant.underline,
        onChanged: (next) => selected = next,
      ),
    );

    await tester.tap(find.text('Three'));
    expect(selected, 2);
  });

  testWidgets('AppTabs underline variant disabled blocks tap', (tester) async {
    var selected = 0;
    await pumpWidgetKit(
      tester,
      AppTabs(
        labels: const ['One', 'Two'],
        selectedIndex: selected,
        variant: AppTabsVariant.underline,
        enabled: false,
        onChanged: (next) => selected = next,
      ),
    );

    await tester.tap(find.text('Two'));
    expect(selected, 0);
  });
}
