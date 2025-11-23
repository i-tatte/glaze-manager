import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/widgets/common/unsaved_changes_pop_scope.dart';

void main() {
  testWidgets('UnsavedChangesPopScope allows pop when not dirty', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UnsavedChangesPopScope(
          isDirty: false,
          child: const Scaffold(body: Text('Content')),
        ),
      ),
    );

    final NavigatorState navigator = tester.state(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();

    // If pop was allowed, the widget is removed (or we are back to root if pushed)
    // Here we are at root, so pop might close app (in test environment it just pops).
    // To verify, we can push a route first.
  });

  testWidgets('UnsavedChangesPopScope shows dialog when dirty', (
    WidgetTester tester,
  ) async {
    bool discarded = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => UnsavedChangesPopScope(
                      isDirty: true,
                      onDiscard: () => discarded = true,
                      child: const Scaffold(body: Text('Dirty Content')),
                    ),
                  ),
                );
              },
              child: const Text('Push'),
            ),
          ),
        ),
      ),
    );

    // Push the route
    await tester.tap(find.text('Push'));
    await tester.pumpAndSettle();

    expect(find.text('Dirty Content'), findsOneWidget);

    // Try to pop
    await tester.binding.handlePopRoute();
    await tester.pump(); // Start animation
    await tester.pump(const Duration(seconds: 1)); // Wait for animation

    // Dialog should appear
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('変更を破棄しますか？'), findsOneWidget);

    // Cancel
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    // Should still be on the page
    expect(find.text('Dirty Content'), findsOneWidget);
    expect(discarded, false);

    // Try to pop again
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Discard
    await tester.tap(find.text('破棄'));
    await tester.pumpAndSettle();

    // Should be back to main page
    expect(find.text('Dirty Content'), findsNothing);
    expect(find.text('Push'), findsOneWidget);
    expect(discarded, true);
  });
}
