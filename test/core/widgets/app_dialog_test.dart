import 'package:alnujom/core/widgets/app_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('AppDialog renders destructive action', (tester) async {
    var acted = false;
    await pumpWidgetKit(
      tester,
      AppDialog(
        title: 'Delete',
        actionLabel: 'Delete',
        variant: AppDialogVariant.destructive,
        onAction: () => acted = true,
      ),
    );

    await tester.tap(find.text('Delete').last);
    expect(acted, isTrue);
  });
}
