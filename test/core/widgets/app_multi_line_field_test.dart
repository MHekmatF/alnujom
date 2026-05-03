import 'package:alnujom/core/widgets/app_multi_line_field.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('AppMultiLineField updates counter', (tester) async {
    await pumpWidgetKit(
      tester,
      const AppMultiLineField(label: 'Description', maxLength: 1000),
    );

    await tester.enterText(find.byType(AppMultiLineField), 'abc');
    await tester.pump();
    expect(find.text('3/1000'), findsOneWidget);
  });
}
