/// Civic Score Badge Widget
///
/// Circular badge displaying civic score with tier color coding.
/// Used by DashboardScreen, CommuteSearchScreen, CommuteDetailScreen,
/// MyMatchesScreen, ProfileScreen.
library;

import 'package:flutter/material.dart';

import '../../core/design/app_colors.dart';

enum CivicScoreBadgeSize { small, medium, large }

class CivicScoreBadge extends StatelessWidget {
  final double score;
  final CivicScoreBadgeSize size;
  final bool showTier;

  const CivicScoreBadge({
    super.key,
    required this.score,
    this.size = CivicScoreBadgeSize.medium,
    this.showTier = false,
  });

  @override
  Widget build(BuildContext context) {
    final dimensions = _dimensions;
    final tierColor = scoreTierColor(score);
    final tierLabel = scoreTierLabel(score);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dimensions,
          height: dimensions,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tierColor.withValues(alpha: 0.15),
            border: Border.all(color: tierColor, width: 2),
          ),
          child: Center(
            child: Text(
              score.toStringAsFixed(0),
              style: TextStyle(
                color: tierColor,
                fontSize: dimensions * 0.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        if (showTier) ...[
          const SizedBox(height: 4),
          Text(
            tierLabel,
            style: TextStyle(
              color: tierColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ],
    );
  }

  double get _dimensions => switch (size) {
        CivicScoreBadgeSize.small => 32,
        CivicScoreBadgeSize.medium => 48,
        CivicScoreBadgeSize.large => 72,
      };
}
