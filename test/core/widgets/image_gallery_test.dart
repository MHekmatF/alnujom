import 'package:alnujom/core/widgets/image_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('ImageGallery renders empty placeholder', (tester) async {
    await pumpWidgetKit(tester, const ImageGallery(imageUrls: []));

    expect(find.byType(ImageGallery), findsOneWidget);
    expect(find.byIcon(Icons.image), findsOneWidget);
  });

  testWidgets('ImageGallery loading variant renders skeleton', (tester) async {
    await pumpWidgetKit(
      tester,
      const ImageGallery(imageUrls: [], loading: true),
    );

    expect(find.byType(ImageGallery), findsOneWidget);
  });

  testWidgets('ImageGallery shows page indicator with non-empty list', (
    tester,
  ) async {
    await pumpWidgetKit(
      tester,
      const ImageGallery(
        imageUrls: ['https://example.com/a', 'https://example.com/b'],
      ),
    );
    await tester.pump();

    expect(find.text('1/2'), findsOneWidget);
  });
}
