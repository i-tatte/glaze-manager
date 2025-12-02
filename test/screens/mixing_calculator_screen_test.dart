import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/screens/mixing_calculator_screen.dart';

void main() {
  group('MixingCalculatorScreen Tests', () {
    final recipe = {'m1': 50.0, 'm2': 30.0, 'm3': 20.0};
    final materialNames = {
      'm1': 'Material 1',
      'm2': 'Material 2',
      'm3': 'Material 3',
    };

    testWidgets('Initial calculation is correct (Total 1000g)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MixingCalculatorScreen(
            recipe: recipe,
            materialNames: materialNames,
          ),
        ),
      );

      // Check Total Weight
      expect(find.widgetWithText(TextField, '1000.0'), findsOneWidget);

      // Check Material Weights
      // m1: 50% of 1000 = 500
      // m2: 30% of 1000 = 300
      // m3: 20% of 1000 = 200
      expect(find.widgetWithText(TextField, '500.0'), findsOneWidget);
      expect(find.widgetWithText(TextField, '300.0'), findsOneWidget);
      expect(find.widgetWithText(TextField, '200.0'), findsOneWidget);
    });

    testWidgets('Updating Total Weight updates all materials', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MixingCalculatorScreen(
            recipe: recipe,
            materialNames: materialNames,
          ),
        ),
      );

      // Find Total Weight input (first TextField)
      final totalInput = find.widgetWithText(TextField, '1000.0').first;
      await tester.enterText(totalInput, '2000');
      await tester.pump();

      // Check Material Weights
      // m1: 50% of 2000 = 1000
      // m2: 30% of 2000 = 600
      // m3: 20% of 2000 = 400
      expect(find.widgetWithText(TextField, '1000.0'), findsOneWidget);
      expect(find.widgetWithText(TextField, '600.0'), findsOneWidget);
      expect(find.widgetWithText(TextField, '400.0'), findsOneWidget);
    });

    testWidgets('Updating Material Weight updates Total and other materials', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MixingCalculatorScreen(
            recipe: recipe,
            materialNames: materialNames,
          ),
        ),
      );

      // Find Material 1 input (initially 500.0)
      // Note: There might be multiple 500.0 if we are unlucky, but here values are distinct enough or we rely on order.
      // Better to find by ancestor Row containing material name.
      final m1Input = find.descendant(
        of: find.widgetWithText(Row, 'Material 1'),
        matching: find.byType(TextField),
      );

      // Change m1 to 1000g (which implies Total = 2000g since m1 is 50%)
      await tester.enterText(m1Input, '1000');
      await tester.pump();

      // Check Total Weight
      // Total should be 2000.0
      // We need to find the total input specifically. It's the one in the top container, not in a list tile.
      // Or just check that '2000.0' exists.
      expect(find.widgetWithText(TextField, '2000.0'), findsOneWidget);

      // Check other materials
      // m2: 30% of 2000 = 600
      expect(find.widgetWithText(TextField, '600.0'), findsOneWidget);
    });
  });
}
