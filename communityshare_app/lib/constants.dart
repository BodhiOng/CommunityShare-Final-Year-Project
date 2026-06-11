import 'package:flutter/material.dart';

class AppColors {
  static const night = Color(0xFF081C15);
  static const forest = Color(0xFF1B4332);
  static const pine = Color(0xFF2D6A4F);
  static const mint = Color(0xFF95D5B2);
  static const sand = Color(0xFFD8F3DC);
  static const sun = Color(0xFFFFB703);
  static const coral = Color(0xFFE76F51);
  static const mist = Color(0xFFE9F5EF);
  static const slate = Color(0xFF6B7C75);
  static const white = Colors.white;

  // Legacy aliases kept during migration from the marketplace fork.
  static const charcoalBlack = night;
  static const deepSlateGray = forest;
  static const mutedTeal = pine;
  static const warmCoral = coral;
  static const coolGray = mist;
  static const softLemonYellow = sun;
}

class AppSpacing {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class AppRadius {
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 28;
}

class AppCopy {
  static const String appName = 'CommunityShare';
  static const String tagline = 'Share essentials. Strengthen communities.';
}

ThemeData buildAppTheme() {
  final ColorScheme colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.pine,
    brightness: Brightness.dark,
    primary: AppColors.mint,
    secondary: AppColors.sun,
    error: AppColors.coral,
    surface: AppColors.forest,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.night,
    fontFamily: 'Georgia',
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.night,
      foregroundColor: AppColors.white,
      centerTitle: false,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: AppColors.forest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.pine, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.forest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.pine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: AppColors.mint.withValues(alpha: 0.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.mint, width: 1.4),
      ),
      labelStyle: const TextStyle(color: AppColors.mist),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.mint,
        foregroundColor: AppColors.night,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.forest,
      contentTextStyle: const TextStyle(color: AppColors.mist),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
