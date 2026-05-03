import 'package:alnujom/core/widgets/location_selector.dart';
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
}
