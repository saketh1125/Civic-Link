/// Error Banner Widget
///
/// Colored banner for displaying error, warning, or info messages.
/// Used across all screens with form submission or API calls.
library;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/design/app_decoration.dart';

enum BannerKind { error, warning, info, success }

/// Deprecated alias kept for call-site compatibility during migration.
@Deprecated('Use BannerKind instead')
typedef ErrorType = BannerKind;

class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;
  final BannerKind type;

  const ErrorBanner({
    super.key,
    required this.message,
    this.onDismiss,
    this.type = BannerKind.error,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final (bg, fg, icon) = _resolveColors(scheme);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 20),
          const Gap(10),
          Expanded(
            child: Text(
              message,
              style: context.textTheme.bodySmall?.copyWith(
                color: fg,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
          if (onDismiss != null)
            InkWell(
              onTap: onDismiss,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, color: fg, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  (Color, Color, IconData) _resolveColors(ColorScheme scheme) {
    switch (type) {
      case BannerKind.error:
        return (
          scheme.errorContainer.withValues(alpha: 0.5),
          scheme.error,
          Icons.error_outline_rounded,
        );
      case BannerKind.warning:
        return (
          scheme.tertiaryContainer.withValues(alpha: 0.4),
          scheme.tertiary,
          Icons.warning_amber_rounded,
        );
      case BannerKind.info:
        return (
          scheme.secondaryContainer.withValues(alpha: 0.4),
          scheme.primary,
          Icons.info_outline_rounded,
        );
      case BannerKind.success:
        return (
          scheme.primaryContainer.withValues(alpha: 0.4),
          scheme.primary,
          Icons.check_circle_outline_rounded,
        );
    }
  }
}
