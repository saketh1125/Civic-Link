/// Commute Search Screen
///
/// Search for available commutes with filters. Redesigned with the design
/// system's GlassCard filter bar, EmptyState, and staggered result list.
///
/// BACKEND BLOCKER: GET /commutes/search is MISSING. Stubbed with GET
/// /commutes/my as placeholder until the endpoint is built.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/design/app_decoration.dart';
import '../../core/design/app_spacing.dart';
import '../../providers/commute_search_provider.dart';
import '../widgets/auth_guard.dart';
import '../widgets/commute_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass_card.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/neon_button.dart';
import '../widgets/staggered_fade_in.dart';
import 'commute_detail_screen.dart';

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
          appBar: AppBar(
            title: const Text('FIND A RIDE'),
            leading: const BackButton(),
          ),
          body: Column(
            children: [
              // ---- Filter bar ------------------------------------------------------
              Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
                child: GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    children: [
                      // Origin
                      TextField(
                        controller: _originController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'Origin area...',
                          prefixIcon: Icon(Icons.location_on_outlined),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                      const Gap(AppSpacing.m),
                      // Destination
                      TextField(
                        controller: _destinationController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _onSearch(),
                        decoration: InputDecoration(
                          hintText: 'Destination area...',
                          prefixIcon: Icon(
                            Icons.location_on_rounded,
                            color: context.colors.primary,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                      const Gap(AppSpacing.l),
                      NeonButton(
                        label: 'SEARCH',
                        icon: Icons.search_rounded,
                        isLoading: searchState.isLoading,
                        onPressed: _onSearch,
                      ),
                    ],
                  ),
                ),
              ),

              // ---- Results ------------------------------------------------------------
              Expanded(
                child: searchState.results.isEmpty && !searchState.isLoading
                    ? const EmptyState(
                        icon: Icons.search_rounded,
                        title: 'No rides found',
                        message: 'Try different filters or search terms',
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets.all(AppSpacing.screenPaddingH)
                                .copyWith(top: 0),
                        itemCount: searchState.results.length,
                        itemBuilder: (context, index) {
                          final commute = searchState.results[index];
                          return StaggeredFadeIn(
                            delay: Duration(milliseconds: 60 * index),
                            child: CommuteCard(
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
                            ),
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
