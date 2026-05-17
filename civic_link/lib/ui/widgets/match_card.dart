/// Match Card Widget
///
/// Card displaying match summary with status, route, and actions.
/// Used by MyMatchesScreen.

import 'package:flutter/material.dart';

import '../../main.dart';

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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSecondaryGrey,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // User avatar placeholder
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kAccentGreen.withOpacity(0.15),
                  ),
                  child: Icon(
                    Icons.person,
                    color: kAccentGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        otherUserName ?? 'User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pickup radius: ${pickupRadiusMeters}m',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),
            if (commuteWasWomenOnly) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.shield, color: Colors.pinkAccent, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Women-only commute',
                    style: TextStyle(
                      color: Colors.pinkAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: actions!
                    .map((a) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: a,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFFEA00);
      case 'confirmed':
        return kAccentGreen;
      case 'in_progress':
        return Colors.blueAccent;
      case 'completed':
        return Colors.greenAccent;
      case 'cancelled':
        return Colors.redAccent;
      default:
        return kHintGrey;
    }
  }
}
