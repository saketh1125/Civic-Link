/// Match Card Widget
///
/// Card displaying match summary with status, route, and actions.
/// Used by MyMatchesScreen.
library;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_decoration.dart';
import '../../core/design/app_status.dart';
import 'status_chip.dart';

class MatchCard extends StatelessWidget {
  final String id;
  final String commuteId;
  final String driverId;
  final String passengerId;
  final String status;
  final int pickupRadiusMeters;
  final bool commuteWasWomenOnly;
  final VoidCallback? onTap;
  final List<Widget>? actions;
  final String? otherUserName;

  const MatchCard({
    super.key,
    required this.id,
    required this.commuteId,
    required this.driverId,
    required this.passengerId,
    required this.status,
    required this.pickupRadiusMeters,
    required this.commuteWasWomenOnly,
    this.onTap,
    this.actions,
    this.otherUserName,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final isDark = context.isDark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.borderMd,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: AppRadii.borderMd,
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: isDark ? 0.5 : 0.8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary.withValues(alpha: 0.15),
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        color: scheme.primary,
                        size: 20,
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            otherUserName ?? 'User',
                            style: context.textTheme.titleSmall?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Gap(2),
                          Text(
                            'Pickup radius: ${pickupRadiusMeters}m',
                            style: context.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusChip(status: civicStatusFromString(status)),
                  ],
                ),
                if (commuteWasWomenOnly) ...[
                  const Gap(8),
                  Row(
                    children: [
                      const Icon(Icons.shield_rounded,
                          color: kSafetyPink, size: 14),
                      const Gap(4),
                      Text(
                        'Women-only commute',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: kSafetyPink,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                if (actions != null && actions!.isNotEmpty) ...[
                  const Gap(12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: actions!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
