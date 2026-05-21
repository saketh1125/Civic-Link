/// My Commutes Screen
///
/// Shows user's commutes in tabs: My Offers / My Requests.
/// Cancel button on each card with confirmation dialog.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart';
import '../../providers/commute_provider.dart';
import '../widgets/auth_guard.dart';
import '../widgets/commute_card.dart';
import '../widgets/loading_overlay.dart';
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
        backgroundColor: kSecondaryGrey,
        title: const Text('Cancel Commute',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to cancel this commute?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('No', style: TextStyle(color: kHintGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, Cancel',
                style: TextStyle(color: Colors.redAccent)),
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
          backgroundColor: kPrimaryBlack,
          appBar: AppBar(
            backgroundColor: kPrimaryBlack,
            elevation: 0,
            title: const Text(
              'MY COMMUTES',
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
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: kAccentGreen,
              labelColor: kAccentGreen,
              unselectedLabelColor: kHintGrey,
              tabs: const [
                Tab(text: 'My Offers'),
                Tab(text: 'My Requests'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // My Offers tab
              _buildCommuteList(commuteState.commutes),
              // My Requests tab
              _buildOffersList(commuteState.offers),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommuteList(List<Commute> commutes) {
    if (commutes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car,
                color: kHintGrey.withOpacity(0.3), size: 64),
            const SizedBox(height: 16),
            Text(
              'No commutes yet',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Offer a ride to get started',
              style: TextStyle(color: kHintGrey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: commutes.length,
      itemBuilder: (context, index) {
        final commute = commutes[index];
        return Column(
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
                    builder: (_) => CommuteDetailScreen(commuteId: commute.id),
                  ),
                );
              },
            ),
            if (commute.status.toLowerCase() == 'active')
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _cancelCommute(commute.id),
                  icon: const Icon(Icons.cancel_outlined,
                      color: Colors.redAccent, size: 16),
                  label: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildOffersList(List<CommuteOffer> offers) {
    if (offers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_walk,
                color: kHintGrey.withOpacity(0.3), size: 64),
            const SizedBox(height: 16),
            Text(
              'No ride requests yet',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search for commutes to request a ride',
              style: TextStyle(color: kHintGrey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: offers.length,
      itemBuilder: (context, index) {
        final offer = offers[index];
        return Card(
          color: kSecondaryGrey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.directions_walk,
                        color: kAccentGreen, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${offer.originAddress} → ${offer.destinationAddress}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        color: kHintGrey, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      offer.preferredDepartureDate,
                      style: TextStyle(color: kHintGrey, fontSize: 13),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.access_time, color: kHintGrey, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      offer.preferredDepartureTime,
                      style: TextStyle(color: kHintGrey, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: offer.status == 'pending'
                            ? const Color(0xFFFFEA00).withOpacity(0.15)
                            : kAccentGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        offer.status.toUpperCase(),
                        style: TextStyle(
                          color: offer.status == 'pending'
                              ? const Color(0xFFFFEA00)
                              : kAccentGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (offer.isWomenOnly) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.pinkAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'WOMEN ONLY',
                          style: TextStyle(
                            color: Colors.pinkAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
