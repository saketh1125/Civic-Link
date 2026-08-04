/// Civic-Link Design System — Spacing Scale
///
/// Consistent spatial rhythm based on an 4-dp base unit.
/// Never use magic numbers — always reach for these tokens.
///
/// With the `gap` package available, prefer `Gap(AppSpacing.m)` for
/// SizedBox equivalents; use these constants for padding / margin.

import 'package:flutter/rendering.dart';

// =============================================================================
// SPACING TOKENS
// =============================================================================

/// Spatial scale base unit = 4.0 dp.
abstract final class AppSpacing {
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double s = 8.0;
  static const double m = 12.0;
  static const double l = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 48.0;
  static const double massive = 64.0;

  // ---- Standard screen padding -------------------------------------------

  /// Standard horizontal padding for full-bleed content (cards, lists).
  static const double screenPaddingH = 24.0;

  /// Standard vertical padding inside screens.
  static const double screenPaddingV = 16.0;

  /// Auth screens use extra-horizontal padding for a focused column.
  static const double authPaddingH = 32.0;

  /// Card internal padding.
  static const double cardPadding = 20.0;

  /// List-item internal padding.
  static const double listTilePadding = 16.0;

  // ---- EdgeInsets shortcuts ------------------------------------------------

  /// Symmetric screen-level padding.
  static const EdgeInsets screenPadding =
      EdgeInsets.symmetric(horizontal: screenPaddingH, vertical: screenPaddingV);

  /// Auth-screen-focused padding.
  static const EdgeInsets authPadding =
      EdgeInsets.symmetric(horizontal: authPaddingH);

  /// Card interior.
  static const EdgeInsets cardPaddingAll = EdgeInsets.all(cardPadding);

  /// Common gap between stacked cards.
  static const EdgeInsets cardGap = EdgeInsets.only(bottom: l);
}
