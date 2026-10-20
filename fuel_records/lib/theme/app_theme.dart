import 'package:flutter/material.dart';

class AppColors {
  // Brand & Accent Colors - Vibrant Amber, Rich Copper & Sunburst Gold
  static const Color primary = Color(0xFFF59E0B); // Luminous Cockpit Amber (Vivid)
  static const Color primaryDark = Color(0xFFBA4E00); // Vibrant Deep Burnished Amber-Orange (5.0:1 contrast on white)
  static const Color primaryLight = Color(0xFFFBBF24); // Warm Sunburst Highlight

  // Status & Telemetry Semantics (Vibrant Complementary Harmony)
  static const Color success = Color(0xFF10B981); // Vibrant Emerald / Full Tank
  static const Color warning = Color(0xFFF59E0B); // Luminous Amber
  static const Color danger = Color(0xFFEF4444); // Redline Crimson
  static const Color info = Color(0xFF14B8A6); // Vibrant Desert Teal / Telemetry (Complementary)
  static const Color purple = Color(0xFFA855F7); // Electric Plum / EXIF Tier 3
  static const Color orange = Color(0xFFF97316); // Blazing Orange / Pit-Stop Tier 4
  static const Color cyan = Color(0xFF14B8A6); // Vibrant Desert Teal

  // Light Mode Surfaces & Canvas (Vibrant Gold & Orange Sunlit Aesthetic)
  static const Color lightScaffold = Color(0xFFFAF2E6); // Sun-Washed Sand Canvas
  static const Color lightSurface = Color(0xFFFFFBF2); // Sunlit Warm Ivory Surface
  static const Color lightSurfaceElevated = Color(0xFFFFE5D0); // Vibrant Peach-Orange Elevated Container
  static const Color lightBorder = Color(0xFFD99B26); // Radiant Metallic Gold Hairline
  static const Color lightBorderSubtle = Color(0xFFF0DCB0); // Soft Radiant Pale Gold Divider

  // Light Mode Typography (Deep Roasted Espresso & Warm Umber)
  static const Color lightTextPrimary = Color(0xFF1E140C); // Deep Espresso Ink (17.5:1 contrast)
  static const Color lightTextSecondary = Color(0xFF5A412D); // Warm Roasted Chestnut (7.9:1 contrast)
  static const Color lightTextMuted = Color(0xFF876543); // Warm Bronze Sepia (4.8:1 contrast)

  // Dark Mode Surfaces & Canvas (Deeper Soft Black & Dark Gray Stealth Aesthetic)
  static const Color darkScaffold = Color(0xFF0A0A0C); // Soft Black Canvas
  static const Color darkSurface = Color(0xFF18191D); // Clean Dark Gray Pod Surface
  static const Color darkSurfaceElevated = Color(0xFF24262D); // Deep Graphite Gray Container
  static const Color darkBorder = Color(0xFF33363F); // Precision Titanium-Charcoal Hairline
  static const Color darkBorderSubtle = Color(0xFF22242B); // Dark Subtle Divider

  // Dark Mode Typography (Crisp Snow Alabaster & Platinum Silver - AAA Tested)
  static const Color darkTextPrimary = Color(0xFFF8FAFC); // Crisp Snow Alabaster (16.2:1 contrast)
  static const Color darkTextSecondary = Color(0xFFCBD5E1); // Crisp Platinum Silver (10.6:1 contrast)
  static const Color darkTextMuted = Color(0xFF94A3B8); // Sleek Cool Slate (6.1:1 contrast)
}

class AppRadii {
  static const double sm = 8.0;
  static const double md = 14.0;
  static const double lg = 18.0;
  static const double xl = 22.0;
  static const double xxl = 28.0;
}

class AppTextStyles {
  /// Automotive-grade telemetry numeral with tabular figures to prevent layout jitter
  static const TextStyle telemetryNumber = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
  );

  /// Tabular regular body text
  static const TextStyle tabularText = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Stamped metal license plate typography
  static const TextStyle licensePlate = TextStyle(
    fontFamily: 'monospace',
    color: Colors.black,
    fontWeight: FontWeight.w900,
    fontSize: 11.5,
    letterSpacing: 1.4,
  );
}

class AppTheme {
  static Color surfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
  }

  static Color elevatedSurfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkSurfaceElevated
        : AppColors.lightSurfaceElevated;
  }

  static Color borderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkBorder
        : AppColors.lightBorder;
  }

  static Color borderSubtleColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkBorderSubtle
        : AppColors.lightBorderSubtle;
  }

  static Color textPrimaryColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
  }

  static Color textSecondaryColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
  }

  static Color textMutedColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkTextMuted
        : AppColors.lightTextMuted;
  }
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryDark,
        brightness: Brightness.light,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
        primary: AppColors.primaryDark,
        onPrimary: Colors.white,
        outline: AppColors.lightBorder,
        outlineVariant: AppColors.lightBorderSubtle,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.lightScaffold,
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: const BorderSide(color: AppColors.lightBorder, width: 1.2),
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
          side: const BorderSide(color: AppColors.lightBorder, width: 1.2),
          foregroundColor: AppColors.lightTextPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.8),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
        primary: AppColors.primary,
        onPrimary: const Color(0xFF0A0A0C),
        outline: AppColors.darkBorder,
        outlineVariant: AppColors.darkBorderSubtle,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.darkScaffold,
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: const BorderSide(color: AppColors.darkBorder, width: 1.2),
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
          backgroundColor: AppColors.primary,
          foregroundColor: const Color(0xFF0A0A0C),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
          side: const BorderSide(color: AppColors.darkBorder, width: 1.2),
          foregroundColor: AppColors.darkTextPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
      ),
    );
  }
}
