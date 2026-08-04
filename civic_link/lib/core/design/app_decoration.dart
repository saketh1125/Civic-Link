/// Civic-Link Design System — Radii, Shadows, Elevation & Motion
///
/// Centralised decoration + motion tokens. Keeps curves/radii/durations
/// consistent across screens without scattering constants.

import 'package:flutter/material.dart';

// =============================================================================
// RADII
// =============================================================================

abstract final class AppRadii {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double pill = 999.0;

  static final BorderRadius borderSm = BorderRadius.circular(sm);
  static final BorderRadius borderMd = BorderRadius.circular(md);
  static final BorderRadius borderLg = BorderRadius.circular(lg);
  static final BorderRadius borderXl = BorderRadius.circular(xl);
  static final BorderRadius borderPill = BorderRadius.circular(pill);
}

// =============================================================================
// SHADOWS / GLOWS
// =============================================================================

abstract final class AppShadows {
  /// Neon glow behind the civic-score ring (dark mode).
  static List<BoxShadow> scoreGlow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.45),
          blurRadius: 24,
          spreadRadius: -4,
        ),
        BoxShadow(
          color: color.withValues(alpha: 0.20),
          blurRadius: 48,
          spreadRadius: -8,
        ),
      ];

  /// Soft card elevation for light mode.
  static List<BoxShadow> cardElevation(Brightness brightness) => brightness ==
          Brightness.light
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ]
      : const [];

  /// Subtle bottom-sheet shadow.
  static List<BoxShadow> sheetShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 24,
      offset: const Offset(0, -4),
    ),
  ];
}

// =============================================================================
// MOTION
// =============================================================================

abstract final class AppMotion {
  // Durations
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration splashHold = Duration(milliseconds: 900);

  // Curves
  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.fastOutSlowIn;
  static const Curve entrance = Curves.easeOutQuart;
  static const Curve exit = Curves.easeInCubic;

  /// Stagger delay between list items.
  static Duration staggerFor(int index) =>
      Duration(milliseconds: (50 * index).clamp(0, 400));
}

// =============================================================================
// CONTEXT EXTENSIONS
// =============================================================================

/// Convenience getters so widgets can write `context.colors.primary`
/// instead of `Theme.of(context).colorScheme.primary`.
extension CivicThemeContext on BuildContext {
  /// Current [ColorScheme].
  ColorScheme get colors => Theme.of(this).colorScheme;

  /// Current [TextTheme].
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Current brightness.
  Brightness get brightness => Theme.of(this).brightness;

  /// True when running in dark mode.
  bool get isDark => brightness == Brightness.dark;

  /// Quick access to the primary scaffold background.
  Color get surface => colors.surface;
}
