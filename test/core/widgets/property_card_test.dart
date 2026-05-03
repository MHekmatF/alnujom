import 'package:alnujom/core/widgets/property_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('PropertyCard renders placeholder and long-press callback', (
    tester,
  ) async {
    var longPressed = false;
    await pumpWidgetKit(
      tester,
      PropertyCard(
        title: 'Home',
        price: '100',
        location: 'Damascus',
        featured: true,
        onLongPress: () => longPressed = true,
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    await tester.longPress(find.byType(PropertyCard));
    expect(longPressed, isTrue);
  });

  testWidgets('PropertyCard favorite state swaps icon, not just color', (
    tester,
  ) async {
    await pumpWidgetKit(
      tester,
      const PropertyCard(
        title: 'A',
        price: '1',
        location: 'X',
        favorite: false,
      ),
    );
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);

    await pumpWidgetKit(
      tester,
      const PropertyCard(
        title: 'A',
        price: '1',
        location: 'X',
        favorite: true,
      ),
    );
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });

  testWidgets('PropertyCard horizontal layout is 280 dp wide', (tester) async {
    await pumpWidgetKit(
      tester,
      const PropertyCard(
        title: 'A',
        price: '1',
        location: 'X',
        layout: PropertyCardLayout.horizontal,
      ),
    );

    final size = tester.getSize(find.byType(PropertyCard));
    expect(size.width, closeTo(280, 2));
  });
}
