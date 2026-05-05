import 'package:alnujom/core/widgets/map_preview.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('MapPreview invokes tap callback', (tester) async {
    var taps = 0;
    await pumpWidgetKit(tester, MapPreview(onTap: () => taps += 1));

    await tester.tap(find.byType(MapPreview));
    expect(taps, 1);
  });
}
