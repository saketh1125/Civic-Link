/// Real-Time Civic Score Dashboard
///
/// Redesigned around the design system: gradient ScoreRing, shared line
/// chart, glass-tinted quick actions, and staggered entrances.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/design/app_decoration.dart';
import '../../core/design/app_text_styles.dart';
import '../../main.dart';
import '../../providers/auth_provider.dart';
import '../../providers/civic_score_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/score_line_chart.dart';
import '../widgets/score_ring.dart';
import '../widgets/section_header.dart';
import '../widgets/staggered_fade_in.dart';
import 'commute_create_screen.dart';
import 'commute_search_screen.dart';
import 'my_commutes_screen.dart';
import 'my_matches_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

// =============================================================================
// DASHBOARD SCREEN
// =============================================================================

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authState = ref.read(authProvider);

      if (authState.accessToken == null || authState.accessToken!.isEmpty) {
        if (!mounted) return;
        ref.read(authProvider.notifier).logout();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }

      final valid =
          await ref.read(authProvider.notifier).checkSessionValidity();
      if (!valid) {
        if (!mounted) return;
        ref.read(authProvider.notifier).logout();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }

      ref.read(civicScoreProvider.notifier).startTelemetry(
            baseUrl: kBaseUrl,
            userId: authState.userId ?? 'unknown',
            authToken: authState.accessToken!,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scoreState = ref.watch(civicScoreProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Gap(12),
              _Header(),
              const Gap(16),
              _ScoreSection(score: scoreState.currentScore),
              const Gap(24),
              _HistorySection(history: scoreState.scoreHistory),
              const Gap(20),
              const _QuickActions(),
              const Gap(20),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// HEADER
// =============================================================================

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Gap(12),
            Text('CIVIC SCORE', style: screenTitle(scheme)),
          ],
        ),
        Row(
          children: [
            IconButton(
              tooltip: 'Profile',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              icon: Icon(
                Icons.person_outline_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ),
            IconButton(
              tooltip: 'Settings',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
              icon: Icon(
                Icons.settings_outlined,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// SCORE SECTION
// =============================================================================

class _ScoreSection extends StatelessWidget {
  const _ScoreSection({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    return StaggeredFadeIn(
      delay: const Duration(milliseconds: 100),
      child: Center(
        child: ScoreRing(score: score, size: 260, strokeWidth: 14),
      ),
    );
  }
}

// =============================================================================
// HISTORY SECTION
// =============================================================================

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.history});

  final List<double> history;

  @override
  Widget build(BuildContext context) {
    return StaggeredFadeIn(
      delay: const Duration(milliseconds: 250),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('History'),
          const Gap(8),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              height: 180,
              child: ScoreLineChart(history: history, showAxisLabels: true),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// QUICK ACTIONS
// =============================================================================

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  static const _destinations = <({Widget screen, IconData icon, String label})>[
    (screen: CommuteSearchScreen(), icon: Icons.search_rounded, label: 'Find Ride'),
    (screen: CommuteCreateScreen(), icon: Icons.add_road_rounded, label: 'Offer Ride'),
    (screen: MyCommutesScreen(), icon: Icons.directions_car_rounded, label: 'My Commutes'),
    (screen: MyMatchesScreen(), icon: Icons.handshake_rounded, label: 'My Matches'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Quick Actions'),
        const Gap(8),
        Row(
          children: List.generate(_destinations.length, (index) {
            final d = _destinations[index];
            return Expanded(
              child: StaggeredFadeIn(
                delay: Duration(milliseconds: 350 + index * 60),
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == _destinations.length - 1 ? 0 : 12,
                  ),
                  child: _ActionTile(
                    icon: d.icon,
                    label: d.label,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => d.screen),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.borderMd,
        splashColor: scheme.primary.withValues(alpha: 0.1),
        highlightColor: scheme.primary.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.08),
            borderRadius: AppRadii.borderMd,
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: scheme.primary, size: 26),
              const Gap(8),
              Text(
                label,
                style: context.textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
