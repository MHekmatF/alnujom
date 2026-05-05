import 'package:alnujom/core/widgets/app_text_field.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('AppTextField renders error helper text', (tester) async {
    await pumpWidgetKit(
      tester,
      const AppTextField(label: 'Name', errorText: 'Required'),
    );

    expect(find.text('Required'), findsOneWidget);
  });
}
