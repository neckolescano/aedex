import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

/// The app theme. Plus Jakarta Sans is the font from the UI design; it is
/// downloaded once by google_fonts and cached (the map needs internet anyway).
ThemeData buildAedexTheme({bool useGoogleFont = true}) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AedexColors.brand,
      primary: AedexColors.brand,
    ),
    scaffoldBackgroundColor: const Color(0xFFE9EEE6),
  );
  // google_fonts 9 builds on the new material_ui package, so its own
  // TextTheme helper returns a different TextTheme type. Styling each
  // TextStyle (a type both packages share) avoids that mismatch.
  TextStyle? font(TextStyle? s) =>
      useGoogleFont ? GoogleFonts.plusJakartaSans(textStyle: s) : s;
  final t = base.textTheme;
  final text = t.copyWith(
    displayLarge: font(t.displayLarge),
    displayMedium: font(t.displayMedium),
    displaySmall: font(t.displaySmall),
    headlineLarge: font(t.headlineLarge),
    headlineMedium: font(t.headlineMedium),
    headlineSmall: font(t.headlineSmall),
    titleLarge: font(t.titleLarge),
    titleMedium: font(t.titleMedium),
    titleSmall: font(t.titleSmall),
    bodyLarge: font(t.bodyLarge),
    bodyMedium: font(t.bodyMedium),
    bodySmall: font(t.bodySmall),
    labelLarge: font(t.labelLarge),
    labelMedium: font(t.labelMedium),
    labelSmall: font(t.labelSmall),
  );
  return base.copyWith(
    textTheme: text.apply(
      bodyColor: AedexColors.ink,
      displayColor: AedexColors.ink,
    ),
    // Pill-shaped buttons, as in the design.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        shape: const StadiumBorder(),
        backgroundColor: Colors.white.withValues(alpha: 0.6),
        side: const BorderSide(color: Color(0xF2FFFFFF)),
        foregroundColor: AedexColors.ink,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
  );
}

/// Light text on dark glass (Hotspots).
class AedexDark {
  static const ground = Color(0xFF0C1511);
  static const text = Color(0xFFF2F5F3);
  static const muted = Color(0xFFB9C9C0);
}
