import 'package:alnujom/core/widgets/price_tag.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('PriceTag renders amount and alternate text', (tester) async {
    await pumpWidgetKit(
      tester,
      const PriceTag(amount: '100', currency: 'USD', altText: '1,000,000 ل.س'),
    );

    expect(find.text('100 USD'), findsOneWidget);
    expect(find.text('1,000,000 ل.س'), findsOneWidget);
  });
}
