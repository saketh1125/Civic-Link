/// Commute Detail Screen
///
/// Shows commute details with driver info and "Request Ride" action.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart';
import '../../providers/commute_provider.dart';
import '../../providers/match_provider.dart';
import '../widgets/auth_guard.dart';
import '../widgets/civic_score_badge.dart';
import '../widgets/error_banner.dart';
import '../widgets/loading_overlay.dart';

class CommuteDetailScreen extends ConsumerStatefulWidget {
  final String commuteId;

  const CommuteDetailScreen({super.key, required this.commuteId});

  @override
  ConsumerState<CommuteDetailScreen> createState() =>
      _CommuteDetailScreenState();
}

class _CommuteDetailScreenState extends ConsumerState<CommuteDetailScreen> {
  CommuteDetail? _commute;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCommute();
  }

  Future<void> _loadCommute() async {
    final detail = await ref
        .read(commuteProvider.notifier)
        .fetchCommuteDetail(widget.commuteId);
    if (mounted) {
      setState(() {
        _commute = detail;
        _isLoading = false;
      });
    }
  }

  Future<void> _requestRide() async {
    final success = await ref
        .read(matchProvider.notifier)
        .requestMatch(widget.commuteId);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride request sent!'),
          backgroundColor: Color(0xFF00E676),
        ),
      );
      Navigator.of(context).pop();
    } else {
      final matchState = ref.read(matchProvider);
      if (matchState.error != null) {
        setState(() => _error = matchState.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchState = ref.watch(matchProvider);

    return AuthGuard(
      child: LoadingOverlay(
        isLoading: _isLoading || matchState.isLoading,
        child: Scaffold(
          backgroundColor: kPrimaryBlack,
          appBar: AppBar(
            backgroundColor: kPrimaryBlack,
            elevation: 0,
            title: const Text(
              'COMMUTE DETAILS',
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
          body: _commute == null
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
                      // Route
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: kSecondaryGrey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on,
                                    color: kAccentGreen, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _commute!.originAddress,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
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
                                height: 24,
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
                                    _commute!.destinationAddress,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Info cards
                      Row(
                        children: [
                          _buildInfoCard(Icons.calendar_today,
                              _commute!.departureDate),
                          const SizedBox(width: 12),
                          _buildInfoCard(
                              Icons.access_time, _commute!.departureTime),
                          const SizedBox(width: 12),
                          _buildInfoCard(
                              Icons.airline_seat_recline_normal,
                              '${_commute!.availableSeats}/${_commute!.totalSeats} seats'),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Driver info
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: kSecondaryGrey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: kAccentGreen.withOpacity(0.15),
                              ),
                              child: Icon(Icons.person,
                                  color: kAccentGreen, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _commute!.driverName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _commute!.driverGender.toUpperCase(),
                                    style: TextStyle(
                                      color: kHintGrey,
                                      fontSize: 12,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_commute!.driverScore != null)
                              CivicScoreBadge(
                                score: _commute!.driverScore!,
                                size: CivicScoreBadgeSize.medium,
                                showTier: true,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Women only badge
                      if (_commute!.isWomenOnly)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.pinkAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.pinkAccent.withOpacity(0.3)),
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
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_commute!.isWomenOnly) const SizedBox(height: 16),

                      // Error
                      if (_error != null) ...[
                        ErrorBanner(message: _error!),
                        const SizedBox(height: 16),
                      ],

                      // Request Ride button
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: matchState.isLoading ? null : _requestRide,
                          child: const Text('REQUEST RIDE'),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kSecondaryGrey,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: kAccentGreen, size: 18),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
