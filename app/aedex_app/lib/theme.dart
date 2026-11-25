import 'package:flutter/material.dart';

import 'models/scan.dart';

/// Colours shared by the whole app.
class AedexColors {
  static const brand = Color(0xFF14402F);
  static const ink = Color(0xFF17211C);
  static const muted = Color(0xFF4F5A54);
  static const surfaceMuted = Color(0xFFF3F5F1);
  static const line = Color(0xFFE3E7E1);

  static const clear = Color(0xFF2F8F5B); // 0 containers
  static const some = Color(0xFFF2C14E); // 1 to 3
  static const high = Color(0xFFC8382B); // 4 or more

  static Color forRisk(RiskLevel risk) => switch (risk) {
    RiskLevel.clear => clear,
    RiskLevel.some => some,
    RiskLevel.high => high,
  };

  /// Text colour that stays readable on top of [forRisk].
  static Color onRisk(RiskLevel risk) =>
      risk == RiskLevel.some ? const Color(0xFF3A2A00) : Colors.white;
}

ThemeData buildAedexTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AedexColors.brand,
      primary: AedexColors.brand,
    ),
    scaffoldBackgroundColor: const Color(0xFFECEFE8),
  );
}
