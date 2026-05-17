/// My Matches Screen
///
/// Shows user's matches with filter chips: Pending / Confirmed / Completed.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart';
import '../../providers/auth_provider.dart';
import '../../providers/match_provider.dart';
import '../widgets/auth_guard.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/match_card.dart';
import 'match_detail_screen.dart';

class MyMatchesScreen extends ConsumerStatefulWidget {
  const MyMatchesScreen({super.key});

  @override
  ConsumerState<MyMatchesScreen> createState() => _MyMatchesScreenState();
}

class _MyMatchesScreenState extends ConsumerState<MyMatchesScreen> {
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(matchProvider.notifier).fetchMyMatches();
    });
  }

  List<Match> _filteredMatches(List<Match> matches) {
    if (_selectedFilter == 'all') return matches;
    return matches
        .where((m) => m.status.toLowerCase() == _selectedFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final matchState = ref.watch(matchProvider);
    final authState = ref.read(authProvider);
    final filtered = _filteredMatches(matchState.matches);

    return AuthGuard(
      child: LoadingOverlay(
        isLoading: matchState.isLoading,
        child: Scaffold(
          backgroundColor: kPrimaryBlack,
          appBar: AppBar(
            backgroundColor: kPrimaryBlack,
            elevation: 0,
            title: const Text(
              'MY MATCHES',
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
          body: Column(
            children: [
              // Filter chips
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: kSecondaryGrey,
                child: Row(
                  children: [
                    _buildFilterChip('all', 'All'),
                    const SizedBox(width: 8),
                    _buildFilterChip('pending', 'Pending'),
                    const SizedBox(width: 8),
                    _buildFilterChip('confirmed', 'Confirmed'),
                    const SizedBox(width: 8),
                    _buildFilterChip('completed', 'Completed'),
                  ],
                ),
              ),

              // Error
              if (matchState.error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.red.shade900.withOpacity(0.3),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          matchState.error!,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              // Match list
              Expanded(
                child: filtered.isEmpty && !matchState.isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.handshake,
                                color: kHintGrey.withOpacity(0.3), size: 64),
                            const SizedBox(height: 16),
                            Text(
                              'No matches yet',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Request a ride to get matched',
                              style: TextStyle(
                                  color: kHintGrey, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final match = filtered[index];
                          final isDriver =
                              match.driverId == authState.userId;
                          final otherName = isDriver
                              ? 'Passenger'
                              : 'Driver';

                          return MatchCard(
                            id: match.id,
                            commuteId: match.commuteId,
                            driverId: match.driverId,
                            passengerId: match.passengerId,
                            status: match.status,
                            pickupRadiusMeters: match.pickupRadiusMeters,
                            commuteWasWomenOnly: match.commuteWasWomenOnly,
                            otherUserName: otherName,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      MatchDetailScreen(matchId: match.id),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? kAccentGreen : kInputFill,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? kPrimaryBlack : kHintGrey,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
