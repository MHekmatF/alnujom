import 'package:alnujom/core/widgets/search_field.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('SearchField accepts typing and loading state', (tester) async {
    await pumpWidgetKit(
      tester,
      const SearchField(loading: true, showFilterIcon: true),
    );

    await tester.enterText(find.byType(SearchField), 'home');
    expect(find.text('home'), findsOneWidget);
  });
}
