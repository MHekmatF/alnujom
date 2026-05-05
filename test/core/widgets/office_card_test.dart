import 'package:alnujom/core/widgets/office_card.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('OfficeCard renders verified badge and visit callback', (
    tester,
  ) async {
    var visited = false;
    await pumpWidgetKit(
      tester,
      OfficeCard(
        name: 'Office',
        listingsCount: 3,
        verified: true,
        onVisit: () => visited = true,
      ),
    );

    expect(find.text('Office'), findsOneWidget);
    await tester.tap(find.byType(OfficeCard));
    expect(visited, isTrue);
  });
}
