import 'package:alnujom/core/widgets/app_number_field.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('AppNumberField renders unit suffix', (tester) async {
    await pumpWidgetKit(
      tester,
      const AppNumberField(label: 'Area', unit: 'م²'),
    );

    expect(find.text('م²'), findsOneWidget);
  });
}
