/// Match Detail Screen
///
/// Themed detail view with status pill, route card, people cards, and
/// status-dependent action area.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_decoration.dart';
import '../../core/design/app_spacing.dart';
import '../../core/design/app_status.dart';
import '../../providers/auth_provider.dart';
import '../../providers/match_provider.dart';
import '../widgets/auth_guard.dart';
import '../widgets/error_banner.dart';
import '../widgets/glass_card.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/neon_button.dart';
import '../widgets/staggered_fade_in.dart';
import '../widgets/status_chip.dart';
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Match confirmed!'),
          backgroundColor: context.colors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchState = ref.watch(matchProvider);
    final authState = ref.read(authProvider);
    final scheme = context.colors;

    return AuthGuard(
      child: LoadingOverlay(
        isLoading: _isLoading || matchState.isLoading,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('MATCH DETAILS'),
            leading: const BackButton(),
          ),
          body: _match == null
              ? Center(
                  child: Text(
                    _error ?? 'Loading...',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPaddingH,
                    vertical: AppSpacing.screenPaddingV,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ---- Status header ------------------------------------------------
                      StaggeredFadeIn(
                        delay: const Duration(milliseconds: 0),
                        child: _StatusHeader(status: _match!.status),
                      ),

                      const Gap(16),

                      // ---- Route ----------------------------------------------------------
                      StaggeredFadeIn(
                        delay: const Duration(milliseconds: 60),
                        child: _RouteCard(
                          origin: _match!.originAddress,
                          destination: _match!.destinationAddress,
                        ),
                      ),

                      const Gap(16),

                      // ---- People ---------------------------------------------------------
                      StaggeredFadeIn(
                        delay: const Duration(milliseconds: 120),
                        child: Row(
                          children: [
                            Expanded(
                              child: _PersonCard(
                                role: 'Driver',
                                name: _match!.driverName,
                                icon: Icons.drive_eta_rounded,
                              ),
                            ),
                            const Gap(12),
                            Expanded(
                              child: _PersonCard(
                                role: 'Passenger',
                                name: _match!.passengerName,
                                icon: Icons.directions_walk_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Gap(16),

                      // ---- Pickup radius --------------------------------------------------
                      StaggeredFadeIn(
                        delay: const Duration(milliseconds: 180),
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.near_me_rounded,
                                color: scheme.primary,
                                size: 20,
                              ),
                              const Gap(12),
                              Expanded(
                                child: Text(
                                  'Pickup radius',
                                  style: context.textTheme.bodyMedium
                                      ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Text(
                                '${_match!.pickupRadiusMeters}m',
                                style: context.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ---- Safety banner ---------------------------------------------------
                      if (_match!.commuteWasWomenOnly) ...[
                        const Gap(16),
                        StaggeredFadeIn(
                          delay: const Duration(milliseconds: 220),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: kSafetyPink.withValues(alpha: 0.10),
                              borderRadius: AppRadii.borderMd,
                              border: Border.all(
                                color: kSafetyPink.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.shield_rounded,
                                  color: kSafetyPink,
                                  size: 18,
                                ),
                                const Gap(10),
                                Text(
                                  'Women-only commute',
                                  style: context.textTheme.bodyMedium
                                      ?.copyWith(
                                    color: kSafetyPink,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      // ---- Error banner ------------------------------------------------------
                      if (_error != null) ...[
                        const Gap(16),
                        ErrorBanner(message: _error!),
                      ],

                      const Gap(24),

                      // ---- Action ----------------------------------------------------------
                      StaggeredFadeIn(
                        delay: const Duration(milliseconds: 260),
                        child: _ActionArea(
                          match: _match!,
                          userId: authState.userId,
                          isLoading: matchState.isLoading,
                          onConfirm: _confirmMatch,
                          onRate: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  RatingScreen(matchId: _match!.id),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

// =============================================================================
// STATUS HEADER
// =============================================================================

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final civicStatus = civicStatusFromString(status);
    return Row(
      children: [
        StatusChip(status: civicStatus, compact: false),
        const Spacer(),
      ],
    );
  }
}

// =============================================================================
// ROUTE CARD
// =============================================================================

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.origin, required this.destination});

  final String origin;
  final String destination;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return GlassCard(
      child: Column(
        children: [
          _RoutePoint(
            icon: Icons.trip_origin_rounded,
            color: scheme.primary,
            address: origin,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: Container(
              width: 2,
              height: 26,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.primary.withValues(alpha: 0.5),
                    scheme.error.withValues(alpha: 0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          _RoutePoint(
            icon: Icons.location_on_rounded,
            color: scheme.error,
            address: destination,
          ),
        ],
      ),
    );
  }
}

class _RoutePoint extends StatelessWidget {
  const _RoutePoint({
    required this.icon,
    required this.color,
    required this.address,
  });

  final IconData icon;
  final Color color;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const Gap(10),
        Expanded(
          child: Text(
            address,
            style: context.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// PERSON CARD
// =============================================================================

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.role,
    required this.name,
    required this.icon,
  });

  final String role;
  final String name;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        children: [
          Icon(icon, color: scheme.primary, size: 26),
          const Gap(8),
          Text(
            role.toUpperCase(),
            style: context.textTheme.labelSmall,
          ),
          const Gap(4),
          Text(
            name,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// ACTION AREA
// =============================================================================

class _ActionArea extends StatelessWidget {
  const _ActionArea({
    required this.match,
    required this.userId,
    required this.isLoading,
    required this.onConfirm,
    required this.onRate,
  });

  final MatchDetail match;
  final String? userId;
  final bool isLoading;
  final VoidCallback onConfirm;
  final VoidCallback onRate;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final isDriver = match.driverId == userId;

    switch (match.status.toLowerCase()) {
      case 'pending':
        if (isDriver) {
          return NeonButton(
            label: 'CONFIRM MATCH',
            icon: Icons.check_circle_outline_rounded,
            isLoading: isLoading,
            onPressed: onConfirm,
          );
        }
        return GlassCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.hourglass_top_rounded,
                color: scheme.onSurfaceVariant,
                size: 20,
              ),
              const Gap(10),
              Text(
                'Waiting for driver to confirm',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );

      case 'confirmed':
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.08),
            borderRadius: AppRadii.borderMd,
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: scheme.primary,
                size: 20,
              ),
              const Gap(10),
              Flexible(
                child: Text(
                  'Match confirmed! Trip starting soon.',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );

      case 'completed':
        return NeonButton(
          label: 'RATE THIS MATCH',
          icon: Icons.star_outline_rounded,
          onPressed: onRate,
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
