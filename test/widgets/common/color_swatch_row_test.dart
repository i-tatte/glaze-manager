import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/lab_color.dart';
import 'package:glaze_manager/widgets/common/color_swatch_row.dart';

void main() {
  testWidgets('手動登録の色（percentage 0）も表示し、小面積の自動解析の色は外す', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ColorSwatchRow(
            colorData: [
              LabColor(l: 50, a: 0, b: 0, percentage: 60),
              LabColor(l: 70, a: 0, b: 0, percentage: 2),
              LabColor(l: 90, a: 0, b: 0, percentage: 0),
            ],
          ),
        ),
      ),
    );

    final circles = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).shape == BoxShape.circle,
    );
    expect(circles, findsNWidgets(2));
  });
}
