/// Civic-Link Design System — Color Tokens
///
/// Single source of truth for the app's color palette.
/// Fully Material 3-compliant dual-theme (light + dark) color schemes.
///
/// Dark theme preserves the existing "tactical neon" identity.
/// Light theme uses a desaturated civic green on clean civic surfaces.
///
/// Usage: `Theme.of(context).colorScheme` or the `context.colors` extension.

import 'package:flutter/material.dart';

// =============================================================================
// BRAND & IDENTITY COLORS (theme-agnostic)
// =============================================================================

/// Neon green — primary brand accent. Used in both themes as `primary`.
const Color kBrandGreen = Color(0xFF00E676);

/// Darker, civic green for light theme primary (better contrast on white).
const Color kBrandGreenCivic = Color(0xFF008744);

/// Women-only / safety badge pink.
const Color kSafetyPink = Color(0xFFF50057);

/// Amber warning.
const Color kWarningAmber = Color(0xFFFFC107);

// =============================================================================
// CIVIC SCORE TIER COLORS
// =============================================================================

/// Score >= 90: cruising state.
const Color kScoreExcellent = Color(0xFF00E676);

/// Score 70–89: warning state.
const Color kScoreWarning = Color(0xFFFFEA00);

/// Score < 70: alert state.
const Color kScoreAlert = Color(0xFFFF1744);

/// Tier color lookup for civic scores.
Color scoreTierColor(double score) {
  if (score >= 90) return kScoreExcellent;
  if (score >= 70) return kScoreWarning;
  return kScoreAlert;
}

/// Tier label lookup for civic scores.
String scoreTierLabel(double score) {
  if (score >= 90) return 'CRUISING';
  if (score >= 70) return 'WARNING';
  return 'ALERT';
}

// =============================================================================
// LIGHT COLOR SCHEME — "Civic Daylight"
// =============================================================================

const ColorScheme kLightColorScheme = ColorScheme.light(
  // Primary
  primary: kBrandGreenCivic,
  onPrimary: Colors.white,
  primaryContainer: Color(0xFFB9F6CA),
  onPrimaryContainer: Color(0xFF002108),

  // Secondary
  secondary: Color(0xFF4E6354),
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFD0E8D6),
  onSecondaryContainer: Color(0xFF0C1F13),

  // Tertiary — used for safety badges & highlights
  tertiary: kSafetyPink,
  onTertiary: Colors.white,
  tertiaryContainer: Color(0xFFFFD9E2),
  onTertiaryContainer: Color(0xFF3E001D),

  // Error
  error: Color(0xFFBA1A1A),
  onError: Colors.white,
  errorContainer: Color(0xFFFFDAD6),
  onErrorContainer: Color(0xFF410002),

  // Surfaces
  surface: Color(0xFFF6FBF4),
  onSurface: Color(0xFF181D18),
  surfaceDim: Color(0xFFD7DBD3),
  surfaceBright: Color(0xFFF6FBF4),
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: Color(0xFFF0F5EF),
  surfaceContainer: Color(0xFFEAEFE8),
  surfaceContainerHigh: Color(0xFFE5EAE3),
  surfaceContainerHighest: Color(0xFFDFE4DD),

  // On-surface variants
  onSurfaceVariant: Color(0xFF414942),

  // Outline
  outline: Color(0xFF717971),
  outlineVariant: Color(0xFFC1C9BF),

  // Inverse
  inverseSurface: Color(0xFF2D322D),
  onInverseSurface: Color(0xFFEEF2EA),
  inversePrimary: Color(0xFF4FDA85),

  // Shadow / scrim
  shadow: Colors.black,
  scrim: Colors.black,
);

// =============================================================================
// DARK COLOR SCHEME — "Tactical Neon"
// =============================================================================

const ColorScheme kDarkColorScheme = ColorScheme.dark(
  // Primary
  primary: kBrandGreen,
  onPrimary: Color(0xFF00391A),
  primaryContainer: Color(0xFF00522A),
  onPrimaryContainer: Color(0xFF97F7B0),

  // Secondary
  secondary: Color(0xFFB5CCBA),
  onSecondary: Color(0xFF213528),
  secondaryContainer: Color(0xFF374B3D),
  onSecondaryContainer: Color(0xFFD0E8D6),

  // Tertiary
  tertiary: Color(0xFFFFB1C4),
  onTertiary: Color(0xFF5C1129),
  tertiaryContainer: Color(0xFF782741),
  onTertiaryContainer: Color(0xFFFFD9E2),

  // Error
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF690005),
  errorContainer: Color(0xFF93000A),
  onErrorContainer: Color(0xFFFFDAD6),

  // Surfaces — preserves the deep-black tactical identity
  surface: Color(0xFF0A0A0A),
  onSurface: Color(0xFFE1E4DF),
  surfaceDim: Color(0xFF0A0A0A),
  surfaceBright: Color(0xFF30322F),
  surfaceContainerLowest: Color(0xFF050505),
  surfaceContainerLow: Color(0xFF121412),
  surfaceContainer: Color(0xFF161816),
  surfaceContainerHigh: Color(0xFF202220),
  surfaceContainerHighest: Color(0xFF2B2D2A),

  // On-surface variants
  onSurfaceVariant: Color(0xFFC1C9BF),

  // Outline
  outline: Color(0xFF8B9389),
  outlineVariant: Color(0xFF414942),

  // Inverse
  inverseSurface: Color(0xFFE1E4DF),
  onInverseSurface: Color(0xFF181D18),
  inversePrimary: kBrandGreenCivic,

  // Shadow / scrim
  shadow: Colors.black,
  scrim: Colors.black,
);

// =============================================================================
// LEGACY COMPATIBILITY BRIDGE
// =============================================================================
//
// These aliases let us migrate screen code incrementally: screens can keep
// importing main.dart's old constants while we refactor. Each alias maps to
// the equivalent semantic role.
//
// REMOVE after Phase 3 migration is complete.
// =============================================================================

/// @deprecated Use Theme.of(context).colorScheme.surface
const Color kPrimaryBlack = Color(0xFF0A0A0A);

/// @deprecated Use Theme.of(context).colorScheme.primary
const Color kAccentGreen = kBrandGreen;

/// @deprecated Use Theme.of(context).colorScheme.surfaceContainer
const Color kSecondaryGrey = Color(0xFF1A1A2E);

/// @deprecated Use Theme.of(context).colorScheme.onSurfaceVariant
const Color kHintGrey = Color(0xFF6B6B80);

/// @deprecated Use Theme.of(context).colorScheme.surfaceContainerHigh
const Color kInputFill = Color(0xFF141428);

/// @deprecated Use scoreTierColor()
const Color kCivicScoreGreen = kScoreExcellent;

/// @deprecated Use scoreTierColor()
const Color kCivicScoreYellow = kScoreWarning;

/// @deprecated Use scoreTierColor()
const Color kCivicScoreRed = kScoreAlert;

/// @deprecated Use Theme.of(context).colorScheme.surface
const Color kDashboardBackground = Color(0xFF0A0A0A);
