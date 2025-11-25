import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/widgets/common/empty_list_placeholder.dart';

void main() {
  testWidgets('EmptyListPlaceholder displays message', (
    WidgetTester tester,
  ) async {
    const message = 'No items found';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EmptyListPlaceholder(message: message)),
      ),
    );

    expect(find.text(message), findsOneWidget);
    expect(find.byType(Center), findsOneWidget);
  });
}
