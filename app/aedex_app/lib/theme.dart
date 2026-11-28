import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models/scan.dart';

/// Colours shared by the whole app: the Patak brand plus the risk colours.
class AedexColors {
  // Patak brand. Contrast rule: never put butter text on white or skyWash;
  // on a butter background, use ink text.
  static const cobalt = Color(0xFF1F3FBF); // primary, buttons, headings
  static const patakBlue = Color(0xFF3F7BFF); // mascot body, accents
  static const butter = Color(0xFFFFD84D); // highlight panels, active tab
  static const skyWash = Color(0xFFEAF2FF); // background, glass tint
  static const ink = Color(0xFF13204A); // text, mascot eyes
  static const blush = Color(0xFFFF8FA3); // mascot cheeks only

  /// The main brand colour. Kept as a second name for [cobalt] so every
  /// place that already says `brand` turns Patak blue without an edit.
  static const brand = cobalt;

  // Neutrals, tinted blue to sit with the Patak colours.
  static const muted = Color(0xFF4A5578);
  static const surfaceMuted = Color(0xFFF2F6FD);
  static const line = Color(0xFFDCE4F2);

  // Risk colours carry meaning, not brand: they stay the same.
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

/// The app theme. Lilita One (chunky and friendly, like Patak) is for the
/// logo and headings; Nunito (rounded and easy to read) is for everything
/// else. google_fonts downloads both once and caches them.
ThemeData buildAedexTheme({bool useGoogleFont = true}) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AedexColors.cobalt,
      primary: AedexColors.cobalt,
      secondary: AedexColors.patakBlue,
      tertiary: AedexColors.butter,
      onTertiary: AedexColors.ink,
    ),
    scaffoldBackgroundColor: AedexColors.skyWash,
  );
  // google_fonts 9 builds on the new material_ui package, so its own
  // TextTheme helper returns a different TextTheme type. Styling each
  // TextStyle (a type both packages share) avoids that mismatch.
  TextStyle? display(TextStyle? s) =>
      useGoogleFont ? GoogleFonts.lilitaOne(textStyle: s) : s;
  TextStyle? body(TextStyle? s) =>
      useGoogleFont ? GoogleFonts.nunito(textStyle: s) : s;
  final t = base.textTheme;
  final text = t.copyWith(
    displayLarge: display(t.displayLarge),
    displayMedium: display(t.displayMedium),
    displaySmall: display(t.displaySmall),
    headlineLarge: display(t.headlineLarge),
    headlineMedium: display(t.headlineMedium),
    headlineSmall: display(t.headlineSmall),
    titleLarge: display(t.titleLarge),
    titleMedium: display(t.titleMedium),
    titleSmall: display(t.titleSmall),
    bodyLarge: body(t.bodyLarge),
    bodyMedium: body(t.bodyMedium),
    bodySmall: body(t.bodySmall),
    labelLarge: body(t.labelLarge),
    labelMedium: body(t.labelMedium),
    labelSmall: body(t.labelSmall),
  );
  return base.copyWith(
    textTheme: text.apply(
      bodyColor: AedexColors.ink,
      displayColor: AedexColors.cobalt,
    ),
    // Pill-shaped buttons, as in the design.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        shape: const StadiumBorder(),
        backgroundColor: Colors.white.withValues(alpha: 0.6),
        side: const BorderSide(color: Color(0xF2FFFFFF)),
        foregroundColor: AedexColors.ink,
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
  );
}

/// A heading in Lilita One. The screen gives its own size (and colour,
/// if not cobalt); the font comes from the theme's headline style, so
/// tests that turn Google Fonts off still work.
TextStyle aedexHeading(BuildContext context, TextStyle style) =>
    Theme.of(context).textTheme.headlineSmall!.merge(style);

/// Light text on dark glass (Hotspots): a deep navy made from Patak ink.
class AedexDark {
  static const ground = Color(0xFF0B1330);
  static const text = Color(0xFFF2F5FF);
  static const muted = Color(0xFFB8C3E0);

  /// Smoky ink glass for markers and chips on the dark map.
  static const glass = Color(0xD10D1638);
}
