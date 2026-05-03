import 'package:alnujom/core/widgets/app_radio_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('AppRadioGroup segmented emits selection', (tester) async {
    int? value;
    await pumpWidgetKit(
      tester,
      AppRadioGroup<int>(
        values: const [1, 2],
        labels: const ['A', 'B'],
        groupValue: 1,
        segmented: true,
        onChanged: (next) => value = next,
      ),
    );

    await tester.tap(find.text('B'));
    expect(value, 2);
  });

  testWidgets('AppRadioGroup radio variant emits selection on tap', (
    tester,
  ) async {
    int? value;
    await pumpWidgetKit(
      tester,
      AppRadioGroup<int>(
        values: const [1, 2, 3],
        labels: const ['One', 'Two', 'Three'],
        groupValue: 1,
        onChanged: (next) => value = next,
      ),
    );

    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));

    await tester.tap(find.text('Three'));
    expect(value, 3);
  });

  testWidgets('AppRadioGroup radio variant disabled blocks tap', (
    tester,
  ) async {
    int? value;
    await pumpWidgetKit(
      tester,
      AppRadioGroup<int>(
        values: const [1, 2],
        labels: const ['A', 'B'],
        groupValue: 1,
        enabled: false,
        onChanged: (next) => value = next,
      ),
    );

    await tester.tap(find.text('B'));
    expect(value, isNull);
  });
}
