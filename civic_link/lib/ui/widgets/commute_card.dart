/// Commute Card Widget
///
/// Card displaying commute summary with origin/destination, time, seats.
/// Used by CommuteSearchScreen and MyCommutesScreen.
library;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_decoration.dart';
import '../../core/design/app_status.dart';
import 'status_chip.dart';

class CommuteCard extends StatelessWidget {
  final String id;
  final String originAddress;
  final String destinationAddress;
  final String departureDate;
  final String departureTime;
  final int availableSeats;
  final int totalSeats;
  final bool isWomenOnly;
  final String status;
  final VoidCallback? onTap;
  final double? driverScore;

  const CommuteCard({
    super.key,
    required this.id,
    required this.originAddress,
    required this.destinationAddress,
    required this.departureDate,
    required this.departureTime,
    required this.availableSeats,
    required this.totalSeats,
    required this.isWomenOnly,
    required this.status,
    this.onTap,
    this.driverScore,
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
                // Route
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            originAddress,
                            style: context.textTheme.titleSmall?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Gap(4),
                          Row(
                            children: [
                              Icon(
                                Icons.arrow_downward_rounded,
                                color: scheme.primary,
                                size: 14,
                              ),
                              const Gap(4),
                              Expanded(
                                child: Text(
                                  destinationAddress,
                                  style: context.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (driverScore != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scoreTierColor(driverScore!)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          driverScore!.toStringAsFixed(0),
                          style: TextStyle(
                            color: scoreTierColor(driverScore!),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
                const Gap(12),
                // Info row
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      icon: Icons.calendar_today_rounded,
                      label: departureDate,
                    ),
                    _InfoChip(
                      icon: Icons.access_time_rounded,
                      label: departureTime,
                    ),
                    _InfoChip(
                      icon: Icons.airline_seat_recline_normal_rounded,
                      label: '$availableSeats/$totalSeats',
                    ),
                    if (isWomenOnly)
                      const _InfoChip(
                        icon: Icons.shield_rounded,
                        label: 'Women',
                        accentColor: kSafetyPink,
                      ),
                    StatusChip(
                      status: civicStatusFromString(status),
                      compact: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small icon + label info chip.
class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.accentColor,
  });

  final IconData icon;
  final String label;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final effective = accentColor ?? scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: effective.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: effective),
          const Gap(4),
          Text(
            label,
            style: TextStyle(
              color: effective,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
