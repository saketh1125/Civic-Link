/// Profile Screen
///
/// Rebuilt on the design system — GlassCards, shared ScoreLineChart and
/// CivicScoreBadge, themed inputs and buttons.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_decoration.dart';
import '../../core/design/app_spacing.dart';
import '../../providers/civic_score_provider.dart';
import '../../providers/profile_provider.dart';
import '../widgets/auth_guard.dart';
import '../widgets/civic_score_badge.dart';
import '../widgets/error_banner.dart';
import '../widgets/glass_card.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/neon_button.dart';
import '../widgets/score_line_chart.dart';
import '../widgets/section_header.dart';
import '../widgets/staggered_fade_in.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileProvider.notifier).loadProfile();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _initControllers(ProfileState profile) {
    if (!_controllersInitialized && profile.name != null) {
      _nameController.text = profile.name ?? '';
      _phoneController.text = profile.phoneNumber ?? '';
      _controllersInitialized = true;
    }
  }

  Future<void> _onSave() async {
    final success = await ref.read(profileProvider.notifier).updateProfile(
          name: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
        );
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated!'),
          backgroundColor: context.colors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final scoreState = ref.watch(civicScoreProvider);
    _initControllers(profile);

    return AuthGuard(
      child: LoadingOverlay(
        isLoading: profile.isLoading,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('PROFILE'),
            leading: const BackButton(),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingH,
              vertical: AppSpacing.screenPaddingV,
            ),
            child: Column(
              children: [
                // ---- Error banner ------------------------------------------------
                if (profile.error != null) ...[
                  ErrorBanner(
                    message: profile.error!,
                    onDismiss: () =>
                        ref.read(profileProvider.notifier).clearError(),
                  ),
                  const Gap(20),
                ],

                // ---- Identity block ----------------------------------------------
                StaggeredFadeIn(
                  delay: const Duration(milliseconds: 0),
                  child: _IdentityBlock(
                    name: profile.name ?? 'User',
                    email: profile.email ?? '',
                    verificationStatus: profile.verificationStatus,
                  ),
                ),

                const Gap(28),

                // ---- Score block --------------------------------------------------
                StaggeredFadeIn(
                  delay: const Duration(milliseconds: 100),
                  child: _ScoreBlock(score: scoreState.currentScore,
                      history: scoreState.scoreHistory),
                ),

                const Gap(20),

                // ---- Edit section ------------------------------------------------
                StaggeredFadeIn(
                  delay: const Duration(milliseconds: 200),
                  child: _EditBlock(
                    nameController: _nameController,
                    phoneController: _phoneController,
                    isSaving: profile.isSaving,
                    onSave: _onSave,
                  ),
                ),

                const Gap(20),

                // ---- Stats section ------------------------------------------------
                StaggeredFadeIn(
                  delay: const Duration(milliseconds: 300),
                  child: _StatsBlock(
                    totalTrips: scoreState.scoreHistory.length,
                  ),
                ),

                const Gap(24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// IDENTITY BLOCK
// =============================================================================

class _IdentityBlock extends StatelessWidget {
  const _IdentityBlock({
    required this.name,
    required this.email,
    required this.verificationStatus,
  });

  final String name;
  final String email;
  final String? verificationStatus;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final isVerified = verificationStatus == 'verified';
    final verifColor =
        isVerified ? scheme.primary : kScoreWarning;

    return Column(
      children: [
        // Avatar
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primary.withValues(alpha: 0.12),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.25),
                blurRadius: 24,
                spreadRadius: -6,
              ),
            ],
          ),
          child: Center(
            child: Text(
              initial,
              style: TextStyle(
                color: scheme.primary,
                fontSize: 40,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const Gap(16),

        // Name
        Text(
          name,
          style: context.textTheme.headlineMedium,
        ),
        const Gap(4),

        // Email (read-only)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_rounded,
                color: scheme.onSurfaceVariant, size: 14),
            const Gap(4),
            Text(
              email,
              style: context.textTheme.bodySmall,
            ),
          ],
        ),
        const Gap(10),

        // Verification badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: verifColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: verifColor.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isVerified
                    ? Icons.verified_rounded
                    : Icons.hourglass_top_rounded,
                color: verifColor,
                size: 14,
              ),
              const Gap(6),
              Text(
                isVerified ? 'VERIFIED' : 'PENDING',
                style: TextStyle(
                  color: verifColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// SCORE BLOCK
// =============================================================================

class _ScoreBlock extends StatelessWidget {
  const _ScoreBlock({required this.score, required this.history});

  final double score;
  final List<double> history;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          const SectionHeader('Civic Score', padding: EdgeInsets.zero),
          const Gap(12),
          CivicScoreBadge(
            score: score,
            size: CivicScoreBadgeSize.large,
            showTier: true,
          ),
          const Gap(20),
          SizedBox(
            height: 100,
            child: history.isEmpty
                ? Center(
                    child: Text(
                      'Take your first trip to see your score history',
                      style: context.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  )
                : ScoreLineChart(history: history, showAxisLabels: false),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// EDIT BLOCK
// =============================================================================

class _EditBlock extends StatelessWidget {
  const _EditBlock({
    required this.nameController,
    required this.phoneController,
    required this.isSaving,
    required this.onSave,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader('Edit Profile', padding: EdgeInsets.zero),
          const Gap(16),
          TextFormField(
            controller: nameController,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const Gap(12),
          TextFormField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(
              labelText: 'Phone',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const Gap(16),
          NeonButton(
            label: 'SAVE CHANGES',
            icon: Icons.save_outlined,
            isLoading: isSaving,
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// STATS BLOCK
// =============================================================================

class _StatsBlock extends StatelessWidget {
  const _StatsBlock({required this.totalTrips});

  final int totalTrips;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader('Stats', padding: EdgeInsets.zero),
          const Gap(4),
          _StatRow(
            label: 'Trips tracked',
            value: '$totalTrips',
            icon: Icons.route_rounded,
            iconColor: scheme.primary,
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const Gap(12),
          Expanded(
            child: Text(
              label,
              style: context.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: context.textTheme.titleSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
