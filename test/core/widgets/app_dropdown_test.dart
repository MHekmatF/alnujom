import 'package:alnujom/core/widgets/app_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('AppDropdown renders selected item', (tester) async {
    await pumpWidgetKit(
      tester,
      const AppDropdown<String>(
        label: 'Type',
        value: 'flat',
        items: [DropdownMenuItem(value: 'flat', child: Text('Flat'))],
      ),
    );

    expect(find.text('Flat'), findsOneWidget);
  });
}
