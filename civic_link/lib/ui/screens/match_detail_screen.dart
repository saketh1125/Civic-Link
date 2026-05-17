/// Match Detail Screen
///
/// Shows match details with status-based action buttons.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart';
import '../../providers/auth_provider.dart';
import '../../providers/match_provider.dart';
import '../widgets/auth_guard.dart';
import '../widgets/error_banner.dart';
import '../widgets/loading_overlay.dart';
import 'rating_screen.dart';

class MatchDetailScreen extends ConsumerStatefulWidget {
  final String matchId;

  const MatchDetailScreen({super.key, required this.matchId});

  @override
  ConsumerState<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends ConsumerState<MatchDetailScreen> {
  MatchDetail? _match;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMatch();
  }

  Future<void> _loadMatch() async {
    final detail = await ref
        .read(matchProvider.notifier)
        .fetchMatchDetail(widget.matchId);
    if (mounted) {
      setState(() {
        _match = detail;
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmMatch() async {
    final success = await ref
        .read(matchProvider.notifier)
        .confirmMatch(widget.matchId);
    if (success && mounted) {
      await _loadMatch();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Match confirmed!'),
          backgroundColor: Color(0xFF00E676),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchState = ref.watch(matchProvider);
    final authState = ref.read(authProvider);

    return AuthGuard(
      child: LoadingOverlay(
        isLoading: _isLoading || matchState.isLoading,
        child: Scaffold(
          backgroundColor: kPrimaryBlack,
          appBar: AppBar(
            backgroundColor: kPrimaryBlack,
            elevation: 0,
            title: const Text(
              'MATCH DETAILS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: _match == null
              ? Center(
                  child: Text(
                    _error ?? 'Loading...',
                    style: TextStyle(color: kHintGrey),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _getStatusColor(_match!.status)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _match!.status.toUpperCase(),
                          style: TextStyle(
                            color: _getStatusColor(_match!.status),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Route
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: kSecondaryGrey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on,
                                    color: kAccentGreen, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _match!.originAddress,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 9),
                              child: Container(
                                width: 2,
                                height: 20,
                                color: kAccentGreen.withOpacity(0.3),
                              ),
                            ),
                            Row(
                              children: [
                                Icon(Icons.location_on,
                                    color: Colors.redAccent, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _match!.destinationAddress,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // People info
                      Row(
                        children: [
                          _buildPersonCard(
                            'Driver',
                            _match!.driverName,
                            Icons.drive_eta,
                          ),
                          const SizedBox(width: 12),
                          _buildPersonCard(
                            'Passenger',
                            _match!.passengerName,
                            Icons.person,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Pickup radius
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: kSecondaryGrey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.near_me,
                                color: kAccentGreen, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              'Pickup radius: ${_match!.pickupRadiusMeters}m',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Safety flags
                      if (_match!.commuteWasWomenOnly)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.pinkAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.shield,
                                  color: Colors.pinkAccent, size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                'Women-only commute',
                                style: TextStyle(
                                  color: Colors.pinkAccent,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_match!.commuteWasWomenOnly)
                        const SizedBox(height: 16),

                      // Error
                      if (_error != null) ...[
                        ErrorBanner(message: _error!),
                        const SizedBox(height: 16),
                      ],

                      // Action buttons based on status
                      _buildActionButtons(authState.userId),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildPersonCard(String role, String name, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSecondaryGrey,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: kAccentGreen, size: 24),
            const SizedBox(height: 8),
            Text(
              role,
              style: TextStyle(color: kHintGrey, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(String? currentUserId) {
    final isDriver = _match!.driverId == currentUserId;

    switch (_match!.status.toLowerCase()) {
      case 'pending':
        if (isDriver) {
          return SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _confirmMatch,
              child: const Text('CONFIRM MATCH'),
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kSecondaryGrey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_empty, color: kHintGrey, size: 20),
              const SizedBox(width: 8),
              Text(
                'Waiting for driver to confirm',
                style: TextStyle(color: kHintGrey),
              ),
            ],
          ),
        );

      case 'confirmed':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kAccentGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: kAccentGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                'Match confirmed! Trip starting soon.',
                style: TextStyle(color: kAccentGreen),
              ),
            ],
          ),
        );

      case 'completed':
        return SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RatingScreen(matchId: _match!.id),
                ),
              );
            },
            child: const Text('RATE THIS MATCH'),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFFEA00);
      case 'confirmed':
        return kAccentGreen;
      case 'completed':
        return Colors.blueAccent;
      case 'cancelled':
        return Colors.redAccent;
      default:
        return kHintGrey;
    }
  }
}
