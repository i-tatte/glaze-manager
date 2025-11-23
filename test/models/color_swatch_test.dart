import 'package:flutter/material.dart' hide ColorSwatch;
import 'package:flutter_test/flutter_test.dart';
import 'package:glaze_manager/models/color_swatch.dart';

void main() {
  group('ColorSwatch Model Test', () {
    test('toMap returns correct map', () {
      final swatch = ColorSwatch(l: 50.0, a: 10.0, b: -10.0, percentage: 0.5);
      final map = swatch.toMap();
      expect(map['L'], 50.0);
      expect(map['a'], 10.0);
      expect(map['b'], -10.0);
      expect(map['percentage'], 0.5);
    });

    test('fromMap creates correct instance', () {
      final map = {'L': 60.0, 'a': -5.0, 'b': 5.0, 'percentage': 0.8};
      final swatch = ColorSwatch.fromMap(map);
      expect(swatch.l, 60.0);
      expect(swatch.a, -5.0);
      expect(swatch.b, 5.0);
      expect(swatch.percentage, 0.8);
    });

    test('deltaE calculates correct color difference', () {
      final swatch1 = ColorSwatch(l: 50, a: 0, b: 0, percentage: 0);
      final swatch2 = ColorSwatch(l: 60, a: 0, b: 0, percentage: 0);
      // Delta E should be 10
      expect(swatch1.deltaE(swatch2), closeTo(10.0, 0.001));
    });

    test('toColor converts Lab to Color', () {
      // Black
      final blackSwatch = ColorSwatch(l: 0, a: 0, b: 0, percentage: 0);
      final blackColor = blackSwatch.toColor();
      expect(blackColor.red, 0);
      expect(blackColor.green, 0);
      expect(blackColor.blue, 0);

      // White (approximate)
      final whiteSwatch = ColorSwatch(l: 100, a: 0, b: 0, percentage: 0);
      final whiteColor = whiteSwatch.toColor();
      // Conversion might not be exactly 255 due to rounding/formula, but should be close
      expect(whiteColor.red, greaterThan(250));
    });

    test('fromColor converts Color to Lab', () {
      const color = Color.fromARGB(255, 0, 0, 0); // Black
      final swatch = ColorSwatch.fromColor(color);
      expect(swatch.l, closeTo(0, 0.1));
      expect(swatch.a, closeTo(0, 0.1));
      expect(swatch.b, closeTo(0, 0.1));
    });

    test('Round trip conversion', () {
      const originalColor = Color.fromARGB(255, 100, 150, 200);
      final swatch = ColorSwatch.fromColor(originalColor);
      final restoredColor = swatch.toColor();

      // Allow for some small loss of precision during conversion
      expect(restoredColor.red, closeTo(originalColor.red, 5));
      expect(restoredColor.green, closeTo(originalColor.green, 5));
      expect(restoredColor.blue, closeTo(originalColor.blue, 5));
    });
  });
}
