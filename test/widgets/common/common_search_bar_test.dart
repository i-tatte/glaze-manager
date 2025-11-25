import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/widgets/common/common_search_bar.dart';

void main() {
  testWidgets('CommonSearchBar displays hint and input', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommonSearchBar(
            controller: controller,
            hintText: 'Search here',
          ),
        ),
      ),
    );

    expect(find.text('Search here'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('CommonSearchBar clear button works', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController();
    bool cleared = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommonSearchBar(
            controller: controller,
            onClear: () => cleared = true,
          ),
        ),
      ),
    );

    // Initially clear button is hidden because text is empty
    expect(find.byIcon(Icons.clear), findsNothing);

    // Enter text
    await tester.enterText(find.byType(TextField), 'test');
    await tester.pump();

    // Clear button should be visible
    expect(find.byIcon(Icons.clear), findsOneWidget);

    // Tap clear button
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(cleared, true);
    expect(find.byIcon(Icons.clear), findsNothing);
  });
}
