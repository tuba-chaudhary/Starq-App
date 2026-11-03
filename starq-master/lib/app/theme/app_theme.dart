import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFFE2000C);      // official STARQ brand red — buttons, CTAs
  static const primaryLight = Color(0xFFFFCCD7); // light pink — backgrounds, badges, highlights
  static const background = Color(0xFFFFFFFF);   // white
  static const textDark = Color(0xFF1D1F23);     // headings, dark text
  static const textLight = Color(0xFF595C61);    // secondary text, subtitles
}

class AppTextStyles {
  static TextStyle heading = GoogleFonts.archivo(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
  );

  static TextStyle subheading = GoogleFonts.archivo(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );

  static TextStyle body = GoogleFonts.inter(
    fontSize: 14,
    color: AppColors.textLight,
  );

  static TextStyle button = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
}

final ThemeData appTheme = ThemeData(
  scaffoldBackgroundColor: AppColors.background,
  primaryColor: AppColors.primary,
  fontFamily: GoogleFonts.inter().fontFamily,   // default fallback font

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.primaryLight.withOpacity(0.2),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),

  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.background,
    elevation: 0,
    titleTextStyle: AppTextStyles.subheading,
    iconTheme: const IconThemeData(color: AppColors.textDark),
  ),
);