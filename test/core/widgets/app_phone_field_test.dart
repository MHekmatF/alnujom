import 'package:alnujom/core/widgets/app_phone_field.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('AppPhoneField emits country code with number', (tester) async {
    var value = '';
    await pumpWidgetKit(
      tester,
      AppPhoneField(label: 'Phone', onChanged: (next) => value = next),
    );

    await tester.enterText(find.byType(AppPhoneField), '123');
    expect(value, '+963123');
  });
}
