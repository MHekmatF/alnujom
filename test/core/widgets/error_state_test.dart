import 'package:alnujom/core/widgets/error_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('ErrorState retry invokes callback', (tester) async {
    var retries = 0;
    await pumpWidgetKit(
      tester,
      ErrorState(title: 'Failed', onRetry: () => retries += 1),
    );

    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });
}
