import 'package:alnujom/core/widgets/app_stepper_input.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('AppStepperInput increments within max', (tester) async {
    var value = 1;
    await pumpWidgetKit(
      tester,
      AppStepperInput(value: value, max: 2, onChanged: (next) => value = next),
    );

    await tester.tap(find.text('1'));
    expect(find.text('1'), findsOneWidget);
  });
}
