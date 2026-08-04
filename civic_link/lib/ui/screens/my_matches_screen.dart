/// My Matches Screen
///
/// Filterable match list. Uses the shared MatchCard + StatusChip and the
/// design-system empty state / filter chips.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/design/app_decoration.dart';
import '../../core/design/app_spacing.dart';
import '../../providers/auth_provider.dart';
import '../../providers/match_provider.dart';
import '../widgets/auth_guard.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_banner.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/match_card.dart';
import '../widgets/staggered_fade_in.dart';
import 'match_detail_screen.dart';

class MyMatchesScreen extends ConsumerStatefulWidget {
  const MyMatchesScreen({super.key});

  @override
  ConsumerState<MyMatchesScreen> createState() => _MyMatchesScreenState();
}

class _MyMatchesScreenState extends ConsumerState<MyMatchesScreen> {
  String _selectedFilter = 'all';

  static const _filters = <(String, String)>[
    ('all', 'All'),
    ('pending', 'Pending'),
    ('confirmed', 'Confirmed'),
    ('completed', 'Completed'),
  ];

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
          appBar: AppBar(
            title: const Text('MY MATCHES'),
            leading: const BackButton(),
          ),
          body: Column(
            children: [
              // ---- Filter bar ---------------------------------------------------
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) => const Gap(8),
                    itemBuilder: (context, index) {
                      final (value, label) = _filters[index];
                      return _FilterChip(
                        label: label,
                        selected: _selectedFilter == value,
                        onSelected: () =>
                            setState(() => _selectedFilter = value),
                      );
                    },
                  ),
                ),
              ),

              // ---- Error banner ---------------------------------------------------
              if (matchState.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ErrorBanner(
                    message: matchState.error!,
                  ),
                ),

              // ---- Match list ------------------------------------------------------
              Expanded(
                child: filtered.isEmpty && !matchState.isLoading
                    ? const EmptyState(
                        icon: Icons.handshake_rounded,
                        title: 'No matches yet',
                        message: 'Request a ride to get matched',
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets.all(AppSpacing.screenPaddingH),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final match = filtered[index];
                          final isDriver =
                              match.driverId == authState.userId;
                          final otherName =
                              isDriver ? 'Passenger' : 'Driver';

                          return StaggeredFadeIn(
                            delay: Duration(milliseconds: 60 * index),
                            child: MatchCard(
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

// =============================================================================
// FILTER CHIP
// =============================================================================

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary
                : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Text(
            label,
            style: context.textTheme.labelLarge?.copyWith(
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
