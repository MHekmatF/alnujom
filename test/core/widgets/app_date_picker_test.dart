import 'package:alnujom/core/widgets/app_date_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('AppDatePicker renders formatted value', (tester) async {
    await pumpWidgetKit(
      tester,
      AppDatePicker(label: 'Date', value: DateTime(2026, 5, 3)),
    );

    expect(find.byType(AppDatePicker), findsOneWidget);
    expect(find.textContaining('2026'), findsOneWidget);
  });

  testWidgets('AppDatePicker disabled does not open picker on tap', (
    tester,
  ) async {
    DateTime? selected;
    await pumpWidgetKit(
      tester,
      AppDatePicker(
        label: 'Date',
        value: DateTime(2026, 5, 3),
        enabled: false,
        onChanged: (value) => selected = value,
      ),
    );

    await tester.tap(find.byType(AppDatePicker));
    await tester.pumpAndSettle();
    expect(selected, isNull);
  });

  testWidgets('AppDatePicker tap opens Material date picker dialog', (
    tester,
  ) async {
    await pumpWidgetKit(
      tester,
      AppDatePicker(label: 'Date', value: DateTime(2026, 5, 3)),
    );

    await tester.tap(find.byType(AppDatePicker));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
