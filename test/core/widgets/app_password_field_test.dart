import 'package:alnujom/core/widgets/app_password_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('AppPasswordField toggles visibility', (tester) async {
    await pumpWidgetKit(tester, const AppPasswordField(label: 'Password'));

    expect(find.byType(AppPasswordField), findsOneWidget);
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(find.byType(AppPasswordField), findsOneWidget);
  });
}
