import 'package:alnujom/core/widgets/category_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('CategoryChip renders selected state', (tester) async {
    var tapped = false;
    await pumpWidgetKit(
      tester,
      CategoryChip(
        label: 'شقق',
        icon: Icons.home,
        selected: true,
        onPressed: () => tapped = true,
      ),
    );

    expect(find.text('شقق'), findsOneWidget);
    await tester.tap(find.text('شقق'));
    expect(tapped, isTrue);
  });
}
