import 'package:flutter/material.dart';

class AppColors {
  // Light Mode Colors
  static const Color lightBackground = Color(0xFFF9F7F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightPrimary = Color(0xFF6D5E56);
  static const Color lightSecondary = Color(0xFFA89F91);
  static const Color lightTextPrimary = Color(0xFF2D2A26);
  static const Color lightTextSecondary = Color(0xFF75706B);
  static const Color lightError = Color(0xFFBA1A1A);

  // Dark Mode Colors
  static const Color darkBackground = Color(0xFF1A1918);
  static const Color darkSurface = Color(0xFF2D2A26);
  static const Color darkPrimary = Color(0xFFD7CFC7);
  static const Color darkSecondary = Color(0xFF5D5852);
  static const Color darkTextPrimary = Color(0xFFF2F0ED); // Brighter Beige
  static const Color darkTextSecondary = Color(0xFFC7BFB5); // Lighter Warm Grey

  // Card Background Colors (Oxidation/Reduction)
  static const Color oxidationCardLight = Color.fromARGB(
    255,
    245,
    232,
    191,
  ); // Amber 50
  static const Color reductionCardLight = Color.fromARGB(
    255,
    194,
    219,
    236,
  ); // Blue 50

  static const Color oxidationCardDark = Color.fromARGB(
    255,
    44,
    38,
    27,
  ); // Warm Dark
  static const Color reductionCardDark = Color.fromARGB(
    255,
    41,
    52,
    59,
  ); // Cool Dark
}
