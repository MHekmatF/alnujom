import 'package:alnujom/core/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('AppButton renders variants and loading hides label', (
    tester,
  ) async {
    var taps = 0;
    await pumpWidgetKit(
      tester,
      Column(
        children: [
          AppButton(label: 'Save', onPressed: () => taps += 1),
          AppButton(label: 'Load', loading: true, onPressed: () => taps += 1),
          AppButton.iconButton(icon: Icons.add, onPressed: () => taps += 1),
        ],
      ),
    );

    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Load'), findsNothing);
    await tester.tap(find.text('Save'));
    expect(taps, 1);
  });
}
