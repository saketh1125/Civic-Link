/// Shared card container with subtle backdrop blur + tinted surface.
///
/// Replaces the ad-hoc "low-opacity white fill + hairline border" pattern
/// previously duplicated across dashboard, profile, detail screens.
/// In light mode it falls back to a soft elevated card (no blur needed).

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/design/app_decoration.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius,
    this.tint,
    this.blur = 12,
    this.showBorder = true,
    this.elevation,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;

  /// Optional colour override for the fill tint (defaults to surface tint).
  final Color? tint;

  /// Blur sigma. 0 disables the BackdropFilter entirely (saves GPU).
  final double blur;

  /// Whether to paint the hairline border (widget lies flat without it).
  final bool showBorder;

  /// Optional extra shadow (defaults derived from brightness).
  final List<BoxShadow>? elevation;

  /// If non-null, the card gets a ripple + tap handling.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = context.brightness;
    final scheme = context.colors;
    final radius = borderRadius ?? AppRadii.borderLg;

    final fillColor = tint ??
        (brightness == Brightness.dark
            ? scheme.surfaceContainerHigh.withValues(alpha: 0.35)
            : scheme.surfaceContainerLow);

    final borderColor = brightness == Brightness.dark
        ? scheme.outlineVariant.withValues(alpha: 0.6)
        : scheme.outlineVariant.withValues(alpha: 0.4);

    final shadows = elevation ?? AppShadows.cardElevation(brightness);

    Widget card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: radius,
        border: showBorder ? Border.all(color: borderColor, width: 1) : null,
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: blur > 0 && brightness == Brightness.dark
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: Padding(padding: padding, child: child),
              )
            : Padding(padding: padding, child: child),
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: card,
      ),
    );
  }
}
