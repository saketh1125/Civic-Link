/// Form tile — tappable row tile used in forms (date, time, seats, toggles).
///
/// Collapses the 5x duplicated `Container(padding:16, kInputFill, radius 12,
/// Row...)` pattern in commute_create_screen into a single themed widget.

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/design/app_decoration.dart';
import '../../core/design/app_spacing.dart';

class FormTile extends StatelessWidget {
  const FormTile({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
    this.accentValue = false,
  });

  final IconData icon;
  final String label;

  /// Displayed value text (right-aligned, primary-coloured when
  /// [accentValue] is true).
  final String? value;

  /// Custom trailing widget (overrides [value] text + chevron).
  final Widget? trailing;

  final VoidCallback? onTap;

  /// Highlight the value with the primary colour (e.g. selected date).
  final bool accentValue;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    Widget content = Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: context.isDark ? 0.5 : 1.0),
        borderRadius: AppRadii.borderMd,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const Gap(AppSpacing.l),
          Expanded(
            child: Text(
              label,
              style: context.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (trailing != null)
            trailing!
          else if (value != null)
            Flexible(
              child: Text(
                value!,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: accentValue ? scheme.primary : scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            )
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
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.borderMd,
          child: content,
        ),
      );
    }
    return content;
  }
}
