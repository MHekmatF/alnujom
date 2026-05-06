import 'package:alnujom/core/widgets/app_currency_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('AppCurrencyField switches currency', (tester) async {
    // Use en locale so segment labels are predictable English text.
    await pumpWidgetKit(
      tester,
      const AppCurrencyField(label: 'Price'),
      direction: TextDirection.ltr,
    );

    // Default selection is USD → currencyUsdName label.
    expect(find.text('US Dollar'), findsWidgets);
    // Tap SYP segment, then verify the AppNumberField unit suffix flipped to
    // the currencySypSymbol value (intentionally identical 'ل.س' in both
    // locales, so the assertion is locale-agnostic).
    await tester.tap(find.text('Syrian Pound'));
    await tester.pump();
    expect(find.text('ل.س'), findsOneWidget);
  });
}
