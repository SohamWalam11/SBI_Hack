/// VeriTrust AI — Digital Twin UI Theme
///
/// Premium dark-mode theme system designed for the YONO 2.0 ecosystem.
/// Features SBI brand palette, glassmorphism effects, and micro-animations.

import 'package:flutter/material.dart';

/// VeriTrust theme data and design tokens.
class DigitalTwinTheme {
  // ── Brand Colors ──────────────────────────────────────────────
  /// SBI Deep Blue
  static const Color primaryDeepBlue = Color(0xFF1A237E);

  /// SBI Blue
  static const Color primaryBlue = Color(0xFF283593);

  /// SBI Light Blue
  static const Color primaryLightBlue = Color(0xFF3949AB);

  /// Gold Accent
  static const Color accentGold = Color(0xFFFFD600);

  /// Warm Gold
  static const Color accentWarmGold = Color(0xFFFFC107);

  /// Success Green (Verified)
  static const Color successGreen = Color(0xFF00C853);

  /// Warning Amber
  static const Color warningAmber = Color(0xFFFF9800);

  /// Error Red (Unverified)
  static const Color errorRed = Color(0xFFFF1744);

  // ── Dark Theme Surfaces ───────────────────────────────────────
  static const Color surfaceDark = Color(0xFF0D1B2A);
  static const Color surfaceCard = Color(0xFF1B2838);
  static const Color surfaceElevated = Color(0xFF243447);
  static const Color surfaceOverlay = Color(0x801B2838); // 50% opacity

  // ── Text Colors ───────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFE0E6ED);
  static const Color textSecondary = Color(0xFF8899A6);
  static const Color textMuted = Color(0xFF5C6B77);

  // ── Glassmorphism ─────────────────────────────────────────────

  /// Frosted glass card decoration
  static BoxDecoration get glassCard => BoxDecoration(
        color: surfaceCard.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      );

  /// Elevated glass decoration for the overlay container
  static BoxDecoration get glassOverlay => BoxDecoration(
        color: surfaceDark.withOpacity(0.92),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: primaryLightBlue.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryDeepBlue.withOpacity(0.4),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      );

  // ── Verification Badges ───────────────────────────────────────

  static BoxDecoration verifiedBadge = BoxDecoration(
    color: successGreen.withOpacity(0.15),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: successGreen.withOpacity(0.3)),
  );

  static BoxDecoration unverifiedBadge = BoxDecoration(
    color: warningAmber.withOpacity(0.15),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: warningAmber.withOpacity(0.3)),
  );

  // ── Typography ────────────────────────────────────────────────

  static const String fontFamily = 'Inter';

  static TextStyle get headingLarge => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle get headingMedium => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: -0.3,
      );

  static TextStyle get bodyLarge => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: textPrimary,
        height: 1.5,
      );

  static TextStyle get bodyMedium => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        height: 1.4,
      );

  static TextStyle get caption => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: textMuted,
        letterSpacing: 0.5,
      );

  static TextStyle get badgeText => const TextStyle(
        fontFamily: fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      );

  // ── Input Decoration ──────────────────────────────────────────

  static InputDecoration get chatInputDecoration => InputDecoration(
        hintText: 'Ask about rates, KYC, policies...',
        hintStyle: bodyMedium.copyWith(color: textMuted),
        filled: true,
        fillColor: surfaceElevated,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.06),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(
            color: primaryLightBlue,
            width: 1.5,
          ),
        ),
      );

  // ── Button Styles ─────────────────────────────────────────────

  static ButtonStyle get primaryButton => ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      );

  static ButtonStyle get accentButton => ElevatedButton.styleFrom(
        backgroundColor: accentGold,
        foregroundColor: primaryDeepBlue,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      );

  // ── Full ThemeData ────────────────────────────────────────────

  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        fontFamily: fontFamily,
        primaryColor: primaryBlue,
        scaffoldBackgroundColor: surfaceDark,
        colorScheme: const ColorScheme.dark(
          primary: primaryBlue,
          secondary: accentGold,
          surface: surfaceCard,
          error: errorRed,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: surfaceDark,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        cardTheme: CardThemeData(
          color: surfaceCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════
//  Animation Utilities
// ═══════════════════════════════════════════════════════════════════

/// Micro-animation curves and durations for the VeriTrust UI.
class VeriTrustAnimations {
  static const Duration messageEntry = Duration(milliseconds: 350);
  static const Duration badgePulse = Duration(milliseconds: 600);
  static const Duration badgeShake = Duration(milliseconds: 400);
  static const Duration overlaySlide = Duration(milliseconds: 400);
  static const Duration typingIndicator = Duration(milliseconds: 800);

  static const Curve messageEntryCurve = Curves.easeOutCubic;
  static const Curve overlayEntryCurve = Curves.easeOutExpo;
  static const Curve badgePulseCurve = Curves.easeInOut;
}
