import 'package:alnujom/core/widgets/chat_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test_support.dart';

void main() {
  testWidgets('ChatBubble renders mine variant', (tester) async {
    await pumpWidgetKit(
      tester,
      const ChatBubble(message: 'Hello', variant: ChatBubbleVariant.mine),
    );

    expect(find.text('Hello'), findsOneWidget);
  });

  // RTL/LTR matrix — T062
  testWidgets(
    'ChatBubble mine aligns to left visual edge under RTL '
    '(AlignmentDirectional.centerEnd → centerLeft in RTL)',
    (tester) async {
      await pumpWidgetKit(
        tester,
        const ChatBubble(message: 'Hi', variant: ChatBubbleVariant.mine),
      );

      final bubbleCenter = tester.getCenter(find.text('Hi'));
      final screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      // AlignmentDirectional.centerEnd resolves to center-left under RTL
      expect(bubbleCenter.dx, lessThan(screenWidth / 2));
    },
  );

  testWidgets('ChatBubble mine aligns to right visual edge under LTR', (
    tester,
  ) async {
    await pumpWidgetKit(
      tester,
      const ChatBubble(message: 'Hi', variant: ChatBubbleVariant.mine),
      direction: TextDirection.ltr,
    );

    final bubbleCenter = tester.getCenter(find.text('Hi'));
    final screenWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    // AlignmentDirectional.centerEnd resolves to center-right under LTR
    expect(bubbleCenter.dx, greaterThan(screenWidth / 2));
  });

  testWidgets('ChatBubble theirs renders without error under LTR', (
    tester,
  ) async {
    await pumpWidgetKit(
      tester,
      const ChatBubble(message: 'Theirs', variant: ChatBubbleVariant.theirs),
      direction: TextDirection.ltr,
    );
    expect(find.text('Theirs'), findsOneWidget);
  });
}
