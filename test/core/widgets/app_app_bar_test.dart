import 'package:alnujom/core/widgets/app_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('AppAppBar back variant fires onBack in RTL', (tester) async {
    var backed = false;
    await pumpWidgetKit(
      tester,
      Scaffold(
        appBar: AppAppBar(
          title: 'Title',
          variant: AppAppBarVariant.withBack,
          onBack: () => backed = true,
        ),
      ),
    );

    expect(find.text('Title'), findsOneWidget);
    expect(find.byIcon(LucideIcons.chevron_right), findsOneWidget);
    await tester.tap(find.byType(IconButton).first);
    expect(backed, isTrue);
  });

  testWidgets('AppAppBar back variant mirrors chevron under LTR', (
    tester,
  ) async {
    await pumpWidgetKit(
      tester,
      const Scaffold(
        appBar: AppAppBar(title: 'Title', variant: AppAppBarVariant.withBack),
      ),
      direction: TextDirection.ltr,
    );

    expect(find.byIcon(LucideIcons.chevron_left), findsOneWidget);
    expect(find.byIcon(LucideIcons.chevron_right), findsNothing);
  });
}
