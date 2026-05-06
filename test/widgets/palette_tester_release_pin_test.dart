import 'package:alnujom/debug/palette_tester.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'PaletteTester renders no output when design tools are disabled',
    (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.rtl,
          child: PaletteTester(designToolsEnabled: false),
        ),
      );

      expect(find.byKey(PaletteTester.chipKey), findsNothing);
      final box = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(box.width, 0);
      expect(box.height, 0);
    },
  );
}
