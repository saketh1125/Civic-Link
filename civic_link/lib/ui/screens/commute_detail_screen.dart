/// Commute Detail Screen
///
/// Themed detail view with route card, info chips, driver block and action.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_decoration.dart';
import '../../core/design/app_spacing.dart';
import '../../providers/commute_provider.dart';
import '../../providers/match_provider.dart';
import '../widgets/auth_guard.dart';
import '../widgets/civic_score_badge.dart';
import '../widgets/error_banner.dart';
import '../widgets/glass_card.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/neon_button.dart';
import '../widgets/staggered_fade_in.dart';

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
        SnackBar(
          content: const Text('Ride request sent!'),
          backgroundColor: context.colors.primary,
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
    final scheme = context.colors;

    return AuthGuard(
      child: LoadingOverlay(
        isLoading: _isLoading || matchState.isLoading,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('COMMUTE DETAILS'),
            leading: const BackButton(),
          ),
          body: _commute == null
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
                      // ---- Route --------------------------------------------------
                      StaggeredFadeIn(
                        delay: const Duration(milliseconds: 0),
                        child: _RouteCard(
                          origin: _commute!.originAddress,
                          destination: _commute!.destinationAddress,
                        ),
                      ),

                      const Gap(16),

                      // ---- Info chips ----------------------------------------------
                      StaggeredFadeIn(
                        delay: const Duration(milliseconds: 80),
                        child: Row(
                          children: [
                            Expanded(
                              child: _InfoCard(
                                icon: Icons.calendar_today_rounded,
                                label: _commute!.departureDate,
                              ),
                            ),
                            const Gap(12),
                            Expanded(
                              child: _InfoCard(
                                icon: Icons.access_time_rounded,
                                label: _commute!.departureTime,
                              ),
                            ),
                            const Gap(12),
                            Expanded(
                              child: _InfoCard(
                                icon: Icons.airline_seat_recline_normal_rounded,
                                label:
                                    '${_commute!.availableSeats}/${_commute!.totalSeats}',
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Gap(16),

                      // ---- Driver -----------------------------------------------------
                      StaggeredFadeIn(
                        delay: const Duration(milliseconds: 160),
                        child: GlassCard(
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      scheme.primary.withValues(alpha: 0.14),
                                ),
                                child: Icon(
                                  Icons.person_rounded,
                                  color: scheme.primary,
                                  size: 26,
                                ),
                              ),
                              const Gap(12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _commute!.driverName,
                                      style:
                                          context.textTheme.titleSmall?.copyWith(
                                        color: scheme.onSurface,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Gap(2),
                                    Text(
                                      _commute!.driverGender.toUpperCase(),
                                      style: context.textTheme.labelSmall,
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
                      ),

                      // ---- Safety banner --------------------------------------------
                      if (_commute!.isWomenOnly) ...[
                        const Gap(16),
                        StaggeredFadeIn(
                          delay: const Duration(milliseconds: 200),
                          child: _SafetyBanner(
                            icon: Icons.shield_rounded,
                            message: 'Women-only commute',
                          ),
                        ),
                      ],

                      // ---- Error -----------------------------------------------------
                      if (_error != null) ...[
                        const Gap(16),
                        ErrorBanner(message: _error!),
                      ],

                      const Gap(24),

                      // ---- Action ------------------------------------------------------
                      StaggeredFadeIn(
                        delay: const Duration(milliseconds: 240),
                        child: NeonButton(
                          label: 'REQUEST RIDE',
                          icon: Icons.hail_rounded,
                          isLoading: matchState.isLoading,
                          onPressed: _requestRide,
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
// SUB-WIDGETS
// =============================================================================

/// Route visual with origin → connector → destination.
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
              height: 28,
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

/// Small icon + label info tile.
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: AppRadii.borderMd,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: scheme.primary, size: 18),
          const Gap(6),
          Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Safety / flag banner (e.g. women-only).
class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    const color = kSafetyPink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const Gap(10),
          Text(
            message,
            style: context.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
