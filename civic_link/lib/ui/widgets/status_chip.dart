/// Status pill — icon + label, colour-mapped from the single `AppStatus` token.
///
/// Replaces the duplicated inline status-chip logic across commute_card,
/// match_card, my_matches_screen, my_commutes_screen, match_detail_screen.

import 'package:flutter/material.dart';

import '../../core/design/app_decoration.dart';
import '../../core/design/app_status.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.status,
    this.compact = false,
  });

  final CivicStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final isDark = context.isDark;
    final color = statusColor(status, scheme, isDark: isDark);
    final label = statusLabel(status);
    final icon = statusIcon(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: color),
          SizedBox(width: compact ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
