import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // --- Spice Market Palette ---
  // Brand
  static const Color primary = Color(0xFFD07318);
  static const Color primaryLight = Color(0xFFEA580C); // Saffron
  static const Color accent = Color(0xFFF59E0B); // Gold / CTA

  // Surfaces
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFFEFCF8); // Near-white warm

  // Chrome
  static const Color appBarBackground = primary; // Match referral code burgundy

  // Semantic
  static const Color pinApproved = Color(0xFF15803D); // Verified trust green
  static const Color pinPending = Color(0xFFEAB308); // Amber
  static const Color error = Color(0xFFB91C1C);

  // Text
  static const Color textPrimary = Color(0xFF451A03); // Deep cocoa
  static const Color textSecondary = Color(0xFF78350F);

  // Borders / dividers
  static const Color border = Color(0xFFE7D7B8);

  // Radii
  static const double radiusCard = 20;
  static const double radiusButton = 12;
  static const double radiusChip = 10;

  // Layout — floating bottom nav bar'ın arkasında kalan içeriğin erişilebilir
  // olması için scroll listelerinin sonuna eklenmesi gereken boşluk.
  static const double bottomNavClearance = 68 + 12 + 16;

  static TextTheme _buildTextTheme(Color onSurface) {
    final body = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.light().textTheme.apply(bodyColor: onSurface, displayColor: onSurface),
    );
    final display = GoogleFonts.fraunces(
      color: onSurface,
      fontWeight: FontWeight.w600,
    );
    return body.copyWith(
      displayLarge: body.displayLarge?.merge(display),
      displayMedium: body.displayMedium?.merge(display),
      displaySmall: body.displaySmall?.merge(display),
      headlineLarge: body.headlineLarge?.merge(display),
      headlineMedium: body.headlineMedium?.merge(display),
      headlineSmall: body.headlineSmall?.merge(display),
      titleLarge: body.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  static ThemeData get lightTheme {
    final textTheme = _buildTextTheme(textPrimary);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: primaryLight,
        tertiary: accent,
        surface: surface,
        error: error,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.fraunces(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusButton),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusButton),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusButton),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        color: surface,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primary.withValues(alpha: 0.08),
        labelStyle: const TextStyle(color: primary, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusChip),
        ),
        side: BorderSide.none,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        backgroundColor: surface,
        type: BottomNavigationBarType.fixed,
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
