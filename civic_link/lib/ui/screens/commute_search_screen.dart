/// Commute Search Screen
///
/// Search for available commutes with filters.
/// BACKEND BLOCKER: GET /commutes/search is MISSING.
/// Stubbed with GET /commutes/my as placeholder.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart';
import '../../providers/commute_search_provider.dart';
import '../widgets/auth_guard.dart';
import '../widgets/commute_card.dart';
import '../widgets/loading_overlay.dart';
import 'commute_detail_screen.dart';

// TODO: BACKEND BLOCKER — GET /commutes/search does not exist.
// Using GET /commutes/my as placeholder until search endpoint is built.

class CommuteSearchScreen extends ConsumerStatefulWidget {
  const CommuteSearchScreen({super.key});

  @override
  ConsumerState<CommuteSearchScreen> createState() =>
      _CommuteSearchScreenState();
}

class _CommuteSearchScreenState extends ConsumerState<CommuteSearchScreen> {
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _onSearch() {
    ref.read(commuteSearchProvider.notifier).search(
          SearchFilters(
            origin: _originController.text.trim(),
            destination: _destinationController.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(commuteSearchProvider);

    return AuthGuard(
      child: LoadingOverlay(
        isLoading: searchState.isLoading,
        message: 'Searching...',
        child: Scaffold(
          backgroundColor: kPrimaryBlack,
          appBar: AppBar(
            backgroundColor: kPrimaryBlack,
            elevation: 0,
            title: const Text(
              'FIND A RIDE',
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
              // Filter bar
              Container(
                padding: const EdgeInsets.all(16),
                color: kSecondaryGrey,
                child: Column(
                  children: [
                    // Origin filter
                    TextField(
                      controller: _originController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Origin area...',
                        hintStyle: TextStyle(color: kHintGrey),
                        prefixIcon:
                            Icon(Icons.location_on, color: kHintGrey, size: 20),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        filled: true,
                        fillColor: kInputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Destination filter
                    TextField(
                      controller: _destinationController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Destination area...',
                        hintStyle: TextStyle(color: kHintGrey),
                        prefixIcon: Icon(Icons.location_on,
                            color: kAccentGreen, size: 20),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        filled: true,
                        fillColor: kInputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Search button
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: searchState.isLoading ? null : _onSearch,
                        child: const Text('SEARCH'),
                      ),
                    ),
                  ],
                ),
              ),

              // Results
              Expanded(
                child: searchState.results.isEmpty && !searchState.isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search,
                                color: kHintGrey.withOpacity(0.3), size: 64),
                            const SizedBox(height: 16),
                            Text(
                              'No rides found',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try different filters',
                              style: TextStyle(
                                color: kHintGrey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: searchState.results.length,
                        itemBuilder: (context, index) {
                          final commute = searchState.results[index];
                          return CommuteCard(
                            id: commute.id,
                            originAddress: commute.originAddress,
                            destinationAddress: commute.destinationAddress,
                            departureDate: commute.departureDate,
                            departureTime: commute.departureTime,
                            availableSeats: commute.availableSeats,
                            totalSeats: commute.totalSeats,
                            isWomenOnly: commute.isWomenOnly,
                            status: commute.status,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CommuteDetailScreen(
                                      commuteId: commute.id),
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
}
