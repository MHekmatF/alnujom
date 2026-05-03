import 'package:alnujom/core/widgets/app_checkbox.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('AppCheckbox emits changed value', (tester) async {
    bool? value;
    await pumpWidgetKit(
      tester,
      AppCheckbox(value: false, onChanged: (next) => value = next),
    );

    await tester.tap(find.byType(AppCheckbox));
    expect(value, isTrue);
  });
}
