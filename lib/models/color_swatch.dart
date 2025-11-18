import 'dart:math';
import 'package:flutter/material.dart';

class ColorSwatch {
  final double l;
  final double a;
  final double b;
  final double percentage;

  ColorSwatch({
    required this.l,
    required this.a,
    required this.b,
    required this.percentage,
  });

  factory ColorSwatch.fromMap(Map<String, dynamic> map) {
    return ColorSwatch(
      l: (map['L'] as num?)?.toDouble() ?? 0.0,
      a: (map['a'] as num?)?.toDouble() ?? 0.0,
      b: (map['b'] as num?)?.toDouble() ?? 0.0,
      percentage: (map['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {'L': l, 'a': a, 'b': b, 'percentage': percentage};
  }

  /// Lab値をFlutterのColor (sRGB) に変換する
  Color toColor() {
    // Step 1: Lab to XYZ
    double y = (l + 16) / 116.0;
    double x = a / 500.0 + y;
    double z = y - this.b / 200.0;

    x = (pow(x, 3) > 0.008856) ? pow(x, 3).toDouble() : (x - 16 / 116) / 7.787;
    y = (pow(y, 3) > 0.008856) ? pow(y, 3).toDouble() : (y - 16 / 116) / 7.787;
    z = (pow(z, 3) > 0.008856) ? pow(z, 3).toDouble() : (z - 16 / 116) / 7.787;

    // Observer= 2°, Illuminant= D65
    x *= 95.047;
    y *= 100.000;
    z *= 108.883;

    // Step 2: XYZ to sRGB
    x /= 100.0;
    y /= 100.0;
    z /= 100.0;

    double r = x * 3.2406 + y * -1.5372 + z * -0.4986;
    double g = x * -0.9689 + y * 1.8758 + z * 0.0415;
    double b = x * 0.0557 + y * -0.2040 + z * 1.0570;

    r = (r > 0.0031308) ? 1.055 * pow(r, 1 / 2.4) - 0.055 : 12.92 * r;
    g = (g > 0.0031308) ? 1.055 * pow(g, 1 / 2.4) - 0.055 : 12.92 * g;
    b = (b > 0.0031308) ? 1.055 * pow(b, 1 / 2.4) - 0.055 : 12.92 * b;

    // 0-255の範囲にクリップ
    int rInt = (r * 255).round().clamp(0, 255);
    int gInt = (g * 255).round().clamp(0, 255);
    int bInt = (b * 255).round().clamp(0, 255);

    return Color.fromARGB(255, rInt, gInt, bInt);
  }

  /// FlutterのColor (sRGB) からLab値を生成する
  factory ColorSwatch.fromColor(Color color) {
    // Step 1: sRGB to XYZ
    double r = color.red / 255.0;
    double g = color.green / 255.0;
    double b = color.blue / 255.0;

    r = (r > 0.04045) ? pow((r + 0.055) / 1.055, 2.4).toDouble() : r / 12.92;
    g = (g > 0.04045) ? pow((g + 0.055) / 1.055, 2.4).toDouble() : g / 12.92;
    b = (b > 0.04045) ? pow((b + 0.055) / 1.055, 2.4).toDouble() : b / 12.92;

    r *= 100.0;
    g *= 100.0;
    b *= 100.0;

    // Observer= 2°, Illuminant= D65
    double x = r * 0.4124 + g * 0.3576 + b * 0.1805;
    double y = r * 0.2126 + g * 0.7152 + b * 0.0722;
    double z = r * 0.0193 + g * 0.1192 + b * 0.9505;

    // Step 2: XYZ to Lab
    x /= 95.047;
    y /= 100.000;
    z /= 108.883;

    x = (x > 0.008856) ? pow(x, 1 / 3).toDouble() : (7.787 * x) + 16 / 116;
    y = (y > 0.008856) ? pow(y, 1 / 3).toDouble() : (7.787 * y) + 16 / 116;
    z = (z > 0.008856) ? pow(z, 1 / 3).toDouble() : (7.787 * z) + 16 / 116;

    final l = (116 * y) - 16;
    final a = 500 * (x - y);
    final bVal = 200 * (y - z);

    return ColorSwatch(l: l, a: a, b: bVal, percentage: 0);
  }
}
