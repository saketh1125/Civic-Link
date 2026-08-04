/// Civic-Link Design System — Typography
///
/// Dual-font strategy:
/// - **Inter** for all UI text (labels, buttons, body) — modern grotesque.
/// - **JetBrains Mono** for the live civic-score number — tactical ledger feel.
///
/// Build a full [TextTheme] once per brightness; screens should never
/// construct raw [TextStyle]s for layout text.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// =============================================================================
// RAW FONT FAMILY HELPERS
// =============================================================================

/// Inter — the app's UI sans-serif.
TextStyle _inter({
  Color? color,
  double? fontSize,
  FontWeight? fontWeight,
  double? letterSpacing,
  double? height,
}) {
  return GoogleFonts.inter(
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: height,
  );
}

/// JetBrains Mono — numeric / telemetry display face.
TextStyle jetBrainsMono({
  Color? color,
  double? fontSize,
  FontWeight? fontWeight,
  double? letterSpacing,
  double? height,
}) {
  return GoogleFonts.jetBrainsMono(
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: height,
  );
}

// =============================================================================
// TEXT THEMES
// =============================================================================

/// Builds a complete [TextTheme] for the given [brightness].
/// [onSurface] / [onSurfaceVariant] come from the active [ColorScheme].
TextTheme buildTextTheme(
  Brightness brightness, {
  required Color onSurface,
  required Color onSurfaceVariant,
}) {
  return TextTheme(
    // ---- Display / Hero score ------------------------------------------------
    displayLarge: jetBrainsMono(
      color: onSurface,
      fontSize: 96,
      fontWeight: FontWeight.w700,
      letterSpacing: -4,
      height: 1.0,
    ),
    displayMedium: jetBrainsMono(
      color: onSurface,
      fontSize: 64,
      fontWeight: FontWeight.w700,
      letterSpacing: -2,
      height: 1.0,
    ),
    displaySmall: _inter(
      color: onSurface,
      fontSize: 36,
      fontWeight: FontWeight.w800,
      letterSpacing: -1,
      height: 1.1,
    ),

    // ---- Headlines -----------------------------------------------------------
    headlineLarge: _inter(
      color: onSurface,
      fontSize: 32,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.5,
      height: 1.15,
    ),
    headlineMedium: _inter(
      color: onSurface,
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.2,
    ),
    headlineSmall: _inter(
      color: onSurface,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.25,
    ),

    // ---- Titles --------------------------------------------------------------
    titleLarge: _inter(
      color: onSurface,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.3,
    ),
    titleMedium: _inter(
      color: onSurface,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
      height: 1.35,
    ),
    titleSmall: _inter(
      color: onSurface,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      height: 1.4,
    ),

    // ---- Body ----------------------------------------------------------------
    bodyLarge: _inter(
      color: onSurface,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.15,
      height: 1.5,
    ),
    bodyMedium: _inter(
      color: onSurface,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
      height: 1.45,
    ),
    bodySmall: _inter(
      color: onSurfaceVariant,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
      height: 1.35,
    ),

    // ---- Labels --------------------------------------------------------------
    labelLarge: _inter(
      color: onSurface,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      height: 1.4,
    ),
    labelMedium: _inter(
      color: onSurfaceVariant,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.35,
    ),
    labelSmall: _inter(
      color: onSurfaceVariant,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.3,
    ),
  );
}

// =============================================================================
// ONE-OFF SEMANTIC TEXT STYLES
// =============================================================================

/// All-caps tracked-out section header (e.g. "HISTORY", "ACCOUNT").
TextStyle sectionHeader(ColorScheme scheme) => _inter(
      color: scheme.primary,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.8,
    );

/// Big all-caps screen title (e.g. "CIVIC SCORE" in the app bar).
TextStyle screenTitle(ColorScheme scheme) => _inter(
      color: scheme.onSurface.withValues(alpha: 0.7),
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 2.0,
    );

/// Score status label (CRUISING / WARNING / ALERT).
TextStyle scoreStatusLabel(Color color) => _inter(
      color: color,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: 3.0,
    );

/// The big score number itself.
TextStyle scoreHeroNumber(Color color) => jetBrainsMono(
      color: color,
      fontSize: 96,
      fontWeight: FontWeight.w700,
      letterSpacing: -4,
      height: 1.0,
    );

/// Small hint / muted text.
TextStyle hintText(ColorScheme scheme) => _inter(
      color: scheme.onSurfaceVariant,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.5,
    );
