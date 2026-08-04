/// Empty state — faded icon, headline, optional hint and CTA button.
///
/// Replaces the 4x duplicated "faded 64px icon + headline + hint" pattern in
/// my_commutes_screen, my_matches_screen, commute_search_screen.

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/design/app_decoration.dart';
import '../../core/design/app_spacing.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final textTheme = context.textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const Gap(AppSpacing.l),
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const Gap(AppSpacing.s),
              Text(
                message!,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const Gap(AppSpacing.xl),
              FilledButton.tonalIcon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
