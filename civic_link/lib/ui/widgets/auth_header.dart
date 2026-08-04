/// Shared logo + title header used on splash/login/registration screens.
///
/// Consolidates the duplicated logo block (green security icon in a circle)
/// previously copied across three screens.

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/design/app_decoration.dart';
import '../../core/design/app_spacing.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    this.iconSize = 36,
    this.circleSize = 72,
    this.titleSize = 28,
    this.subtitle = 'Traffic Police • Pooling Platform',
  });

  final double iconSize;
  final double circleSize;
  final double titleSize;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final textTheme = context.textTheme;

    return Column(
      children: [
        Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primary.withValues(alpha: 0.1),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.4),
              width: 2,
            ),
            boxShadow: context.isDark
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.25),
                      blurRadius: 24,
                      spreadRadius: -6,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.15),
                      blurRadius: 20,
                      spreadRadius: -8,
                    ),
                  ],
          ),
          child: Icon(
            Icons.security_rounded,
            color: scheme.primary,
            size: iconSize,
          ),
        ),
        const Gap(AppSpacing.xl),
        Text(
          'CIVIC-LINK',
          style: textTheme.displaySmall?.copyWith(
            fontSize: titleSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
            color: scheme.onSurface,
          ),
        ),
        const Gap(AppSpacing.xs),
        Text(
          subtitle,
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
