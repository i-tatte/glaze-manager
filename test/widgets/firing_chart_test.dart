import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/widgets/firing_chart.dart';

void main() {
  testWidgets('FiringChart renders with valid data', (
    WidgetTester tester,
  ) async {
    const curveData = '''
    0, 20
    60, 100
    120, 500
    ''';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FiringChart(curveData: curveData)),
      ),
    );

    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('FiringChart renders empty with invalid data', (
    WidgetTester tester,
  ) async {
    const curveData = 'invalid';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FiringChart(curveData: curveData)),
      ),
    );

    expect(find.byType(LineChart), findsNothing);
    expect(find.byType(SizedBox), findsOneWidget);
  });

  testWidgets('FiringChart handles reduction range', (
    WidgetTester tester,
  ) async {
    const curveData = '''
    0, 20
    60, 1000
    120, 1200
    ''';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FiringChart(
            curveData: curveData,
            isReduction: true,
            reductionStartTemp: 900,
            reductionEndTemp: 1100,
          ),
        ),
      ),
    );

    expect(find.byType(LineChart), findsOneWidget);
    // Verifying internal state of LineChart is hard, but we verify it renders.
  });
}
