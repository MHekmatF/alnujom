import 'package:alnujom/core/widgets/chat_bubble.dart';
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
}
