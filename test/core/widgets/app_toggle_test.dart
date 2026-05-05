import 'package:alnujom/core/widgets/app_toggle.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('AppToggle emits changed value', (tester) async {
    var value = false;
    await pumpWidgetKit(
      tester,
      AppToggle(value: value, onChanged: (next) => value = next),
    );

    await tester.tap(find.byType(AppToggle));
    expect(value, isTrue);
  });
}
