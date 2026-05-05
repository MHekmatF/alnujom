import 'package:alnujom/core/widgets/stepper_indicator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('StepperIndicator renders progress label', (tester) async {
    await pumpWidgetKit(
      tester,
      const StepperIndicator(steps: 3, currentIndex: 1),
    );

    expect(find.text('(2/3)'), findsOneWidget);
  });
}
