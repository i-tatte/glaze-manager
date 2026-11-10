import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/firing_profile.dart';
import 'package:glaze_manager/widgets/firing_chart.dart';

void main() {
  test('fromProfile は還元の値を引き継ぐ', () {
    final chart = FiringChart.fromProfile(
      FiringProfile(
        name: 'p',
        curveData: '60, 100',
        isReduction: true,
        reductionStartTemp: 900,
        reductionEndTemp: 1100,
      ),
      duration: Duration.zero,
    );
    expect(chart.curveData, '60, 100');
    expect(chart.isReduction, isTrue);
    expect(chart.reductionStartTemp, 900);
    expect(chart.reductionEndTemp, 1100);
    expect(chart.duration, Duration.zero);

    final empty = FiringChart.fromProfile(FiringProfile(name: 'q'));
    expect(empty.curveData, '');
    expect(empty.isReduction, isFalse);
  });

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
