/// Civic Score Badge Widget
///
/// Circular badge displaying civic score with tier color coding.
/// Used by DashboardScreen, CommuteSearchScreen, CommuteDetailScreen,
/// MyMatchesScreen, ProfileScreen.

import 'package:flutter/material.dart';

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
    final dimensions = _getDimensions();
    final tierColor = _getTierColor();
    final tierLabel = _getTierLabel();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dimensions,
          height: dimensions,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tierColor.withOpacity(0.15),
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

  double _getDimensions() {
    switch (size) {
      case CivicScoreBadgeSize.small:
        return 32;
      case CivicScoreBadgeSize.medium:
        return 48;
      case CivicScoreBadgeSize.large:
        return 72;
    }
  }

  Color _getTierColor() {
    if (score >= 90) return const Color(0xFF00E676);
    if (score >= 70) return const Color(0xFFFFEA00);
    return const Color(0xFFFF1744);
  }

  String _getTierLabel() {
    if (score >= 90) return 'CRUISING';
    if (score >= 70) return 'WARNING';
    return 'ALERT';
  }
}
