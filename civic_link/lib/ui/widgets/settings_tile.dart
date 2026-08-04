/// Settings row — icon + label + optional trailing widget + optional subtitle.
/// Replaces the duplicated `_buildTile` pattern inside settings/profile.

import 'package:flutter/material.dart';

import '../../core/design/app_decoration.dart';
import '../../core/design/app_spacing.dart';

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.iconColor,
    this.titleColor,
    this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? iconColor;
  final Color? titleColor;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final effectiveIconColor = isDestructive
        ? scheme.error
        : (iconColor ?? scheme.primary);
    final effectiveTitleColor = isDestructive
        ? scheme.error
        : (titleColor ?? scheme.onSurface);

    Widget row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.listTilePadding,
        vertical: AppSpacing.m,
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: effectiveIconColor),
          const SizedBox(width: AppSpacing.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: effectiveTitleColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
              size: 20,
            ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: AppRadii.borderMd,
        child: row,
      );
    }
    return row;
  }
}
