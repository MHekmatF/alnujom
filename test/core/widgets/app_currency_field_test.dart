import 'package:alnujom/core/widgets/app_currency_field.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('AppCurrencyField switches currency', (tester) async {
    await pumpWidgetKit(tester, const AppCurrencyField(label: 'Price'));

    expect(find.text('USD'), findsWidgets);
    await tester.tap(find.text('SYP'));
    await tester.pump();
    expect(find.text('ل.س'), findsOneWidget);
  });
}
