/// Commute Card Widget
///
/// Card displaying commute summary with origin/destination, time, seats.
/// Used by CommuteSearchScreen and MyCommutesScreen.

import 'package:flutter/material.dart';

import '../../main.dart';

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
            // Route
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        originAddress,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.arrow_downward,
                              color: kAccentGreen, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              destinationAddress,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getScoreColor(driverScore!).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      driverScore!.toStringAsFixed(0),
                      style: TextStyle(
                        color: _getScoreColor(driverScore!),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Info row
            Row(
              children: [
                _buildChip(Icons.calendar_today, departureDate),
                const SizedBox(width: 8),
                _buildChip(Icons.access_time, departureTime),
                const SizedBox(width: 8),
                _buildChip(Icons.airline_seat_recline_normal,
                    '$availableSeats/$totalSeats'),
                if (isWomenOnly) ...[
                  const SizedBox(width: 8),
                  _buildChip(Icons.shield, 'Women', color: Colors.pinkAccent),
                ],
                const Spacer(),
                _buildStatusChip(status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? kHintGrey).withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color ?? kHintGrey),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color ?? kHintGrey,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return kAccentGreen;
      case 'pending':
        return const Color(0xFFFFEA00);
      case 'completed':
        return Colors.blueAccent;
      case 'cancelled':
        return Colors.redAccent;
      default:
        return kHintGrey;
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return const Color(0xFF00E676);
    if (score >= 70) return const Color(0xFFFFEA00);
    return const Color(0xFFFF1744);
  }
}
