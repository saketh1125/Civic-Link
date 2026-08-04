/// My Commutes Screen
///
/// Tabs: My Offers / My Requests. Redesigned with shared CommuteCard,
/// EmptyState and StatusChip widgets.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_decoration.dart';
import '../../core/design/app_spacing.dart';
import '../../core/design/app_status.dart';
import '../../providers/commute_provider.dart';
import '../widgets/auth_guard.dart';
import '../widgets/commute_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/staggered_fade_in.dart';
import '../widgets/status_chip.dart';
import 'commute_detail_screen.dart';

class MyCommutesScreen extends ConsumerStatefulWidget {
  const MyCommutesScreen({super.key});

  @override
  ConsumerState<MyCommutesScreen> createState() => _MyCommutesScreenState();
}

class _MyCommutesScreenState extends ConsumerState<MyCommutesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(commuteProvider.notifier).fetchMyCommutes();
      ref.read(commuteProvider.notifier).fetchMyOffers();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cancelCommute(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: context.colors.tertiary,
          size: 32,
        ),
        title: const Text('Cancel Commute'),
        content:
            const Text('Are you sure you want to cancel this commute?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.error,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(commuteProvider.notifier).cancelCommute(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commuteState = ref.watch(commuteProvider);

    return AuthGuard(
      child: LoadingOverlay(
        isLoading: commuteState.isLoading,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('MY COMMUTES'),
            leading: const BackButton(),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'My Offers'),
                Tab(text: 'My Requests'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildCommuteList(commuteState.commutes),
              _buildOffersList(commuteState.offers),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommuteList(List<Commute> commutes) {
    if (commutes.isEmpty) {
      return const EmptyState(
        icon: Icons.directions_car_rounded,
        title: 'No commutes yet',
        message: 'Offer a ride to get started',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
      itemCount: commutes.length,
      itemBuilder: (context, index) {
        final commute = commutes[index];
        return StaggeredFadeIn(
          delay: Duration(milliseconds: 60 * index),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CommuteCard(
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
                      builder: (_) =>
                          CommuteDetailScreen(commuteId: commute.id),
                    ),
                  );
                },
              ),
              if (commute.status.toLowerCase() == 'active')
                Padding(
                  padding: const EdgeInsets.only(right: 4, top: 4),
                  child: TextButton.icon(
                    onPressed: () => _cancelCommute(commute.id),
                    icon: Icon(
                      Icons.cancel_outlined,
                      color: context.colors.error,
                      size: 16,
                    ),
                    label: Text(
                      'Cancel',
                      style: TextStyle(
                        color: context.colors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOffersList(List<CommuteOffer> offers) {
    if (offers.isEmpty) {
      return const EmptyState(
        icon: Icons.directions_walk_rounded,
        title: 'No ride requests yet',
        message: 'Search for commutes to request a ride',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
      itemCount: offers.length,
      itemBuilder: (context, index) {
        final offer = offers[index];
        return StaggeredFadeIn(
          delay: Duration(milliseconds: 60 * index),
          child: _OfferCard(offer: offer),
        );
      },
    );
  }
}

// =============================================================================
// OFFER CARD — extracted from inline list-builder duplicate
// =============================================================================

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer});

  final CommuteOffer offer;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final isDark = context.isDark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: AppRadii.borderMd,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.5 : 0.8),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.directions_walk_rounded,
                  color: scheme.primary,
                  size: 20,
                ),
                const Gap(10),
                Expanded(
                  child: Text(
                    '${offer.originAddress} → ${offer.destinationAddress}',
                    style: context.textTheme.titleSmall?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Gap(10),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  color: scheme.onSurfaceVariant,
                  size: 14,
                ),
                const Gap(4),
                Text(
                  offer.preferredDepartureDate,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Gap(16),
                Icon(
                  Icons.access_time_rounded,
                  color: scheme.onSurfaceVariant,
                  size: 14,
                ),
                const Gap(4),
                Text(
                  offer.preferredDepartureTime,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Gap(10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusChip(
                  status: civicStatusFromString(offer.status),
                  compact: true,
                ),
                if (offer.isWomenOnly)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: kSafetyPink.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: kSafetyPink.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Text(
                      'WOMEN ONLY',
                      style: TextStyle(
                        color: kSafetyPink,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
