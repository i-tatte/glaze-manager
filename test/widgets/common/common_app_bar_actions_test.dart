import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/widgets/common/common_app_bar_actions.dart';

void main() {
  testWidgets('CommonAppBarActions shows loading indicator', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [CommonAppBarActions(isLoading: true, onSave: () {})],
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.save), findsNothing);
  });

  testWidgets('CommonAppBarActions shows save and delete buttons', (
    WidgetTester tester,
  ) async {
    bool saved = false;
    bool deleted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              CommonAppBarActions(
                isLoading: false,
                onSave: () => saved = true,
                onDelete: () => deleted = true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.save), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.save));
    expect(saved, true);

    await tester.tap(find.byIcon(Icons.delete_outline));
    expect(deleted, true);
  });

  testWidgets('CommonAppBarActions hides delete button if hasDelete is false', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              CommonAppBarActions(
                isLoading: false,
                onSave: () {},
                hasDelete: false,
                onDelete: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.byIcon(Icons.save), findsOneWidget);
  });
}
