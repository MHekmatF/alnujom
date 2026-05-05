import 'package:alnujom/core/widgets/app_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('AppBottomSheet renders sticky footer', (tester) async {
    await pumpWidgetKit(
      tester,
      const AppBottomSheet(footer: Text('Footer'), child: Text('Body')),
    );

    expect(find.text('Body'), findsOneWidget);
    expect(find.text('Footer'), findsOneWidget);
  });
}
