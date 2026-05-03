import 'package:alnujom/core/widgets/loading_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('LoadingState renders skeleton helpers', (tester) async {
    await pumpWidgetKit(tester, const LoadingState.avatar());

    expect(find.byType(LoadingState), findsOneWidget);
  });
}
