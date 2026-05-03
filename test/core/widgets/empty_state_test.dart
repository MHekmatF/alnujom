import 'package:alnujom/core/widgets/empty_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('EmptyState collapses optional sections', (tester) async {
    await pumpWidgetKit(tester, const EmptyState(headline: 'No data'));

    expect(find.text('No data'), findsOneWidget);
  });
}
