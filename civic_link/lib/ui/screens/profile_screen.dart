/// Profile Screen
///
/// Shows user profile with avatar, civic score, edit form, and stats.
/// Wrapped in AuthGuard.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../main.dart';
import '../../providers/civic_score_provider.dart';
import '../../providers/profile_provider.dart';
import '../widgets/auth_guard.dart';
import '../widgets/civic_score_badge.dart';
import '../widgets/error_banner.dart';
import '../widgets/loading_overlay.dart';

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
        const SnackBar(
          content: Text('Profile updated!'),
          backgroundColor: Color(0xFF00E676),
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
          backgroundColor: kPrimaryBlack,
          appBar: AppBar(
            backgroundColor: kPrimaryBlack,
            elevation: 0,
            title: const Text(
              'PROFILE',
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
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Error banner
                if (profile.error != null) ...[
                  ErrorBanner(
                    message: profile.error!,
                    onDismiss: () =>
                        ref.read(profileProvider.notifier).clearError(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Avatar
                _buildAvatar(profile.name ?? 'U'),
                const SizedBox(height: 16),

                // Name
                Text(
                  profile.name ?? 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),

                // Email domain (read-only)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, color: kHintGrey, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      profile.email ?? '',
                      style: TextStyle(color: kHintGrey, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Verification badge
                _buildVerificationBadge(profile.verificationStatus),
                const SizedBox(height: 32),

                // Civic Score Section
                _buildScoreSection(scoreState),
                const SizedBox(height: 32),

                // Edit Profile Section
                _buildEditSection(profile),
                const SizedBox(height: 32),

                // Stats Section
                _buildStatsSection(scoreState),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kAccentGreen.withOpacity(0.15),
        border: Border.all(color: kAccentGreen, width: 2),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: kAccentGreen,
            fontSize: 32,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationBadge(String? status) {
    final isVerified = status == 'verified';
    final color = isVerified ? kAccentGreen : const Color(0xFFFFEA00);
    final label = isVerified ? 'VERIFIED' : 'PENDING';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVerified ? Icons.verified : Icons.hourglass_empty,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreSection(CivicScoreState scoreState) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSecondaryGrey,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'CIVIC SCORE',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          CivicScoreBadge(
            score: scoreState.currentScore,
            size: CivicScoreBadgeSize.large,
            showTier: true,
          ),
          const SizedBox(height: 20),
          // Score history chart
          SizedBox(
            height: 100,
            child: _buildScoreChart(scoreState),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreChart(CivicScoreState scoreState) {
    final spots = scoreState.scoreHistory.reversed.toList().asMap().entries.map(
      (entry) {
        return FlSpot(entry.key.toDouble(), entry.value);
      },
    ).toList();

    if (spots.isEmpty) {
      return Center(
        child: Text(
          'Take your first trip to see your score history',
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: scoreState.scoreColor,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scoreState.scoreColor.withOpacity(0.3),
                  scoreState.scoreColor.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: const LineTouchData(enabled: false),
      ),
    );
  }

  Widget _buildEditSection(ProfileState profile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSecondaryGrey,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EDIT PROFILE',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          // Name field
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Name',
              labelStyle: TextStyle(color: kHintGrey),
              prefixIcon: Icon(Icons.person_outline, color: kHintGrey),
              filled: true,
              fillColor: kInputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Phone field
          TextField(
            controller: _phoneController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Phone',
              labelStyle: TextStyle(color: kHintGrey),
              prefixIcon: Icon(Icons.phone_outlined, color: kHintGrey),
              filled: true,
              fillColor: kInputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Save button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: profile.isSaving ? null : _onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentGreen,
                foregroundColor: kPrimaryBlack,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: profile.isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: kPrimaryBlack,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'SAVE',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(CivicScoreState scoreState) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSecondaryGrey,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STATS',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatRow('Total trips', '${scoreState.scoreHistory.length}'),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: kHintGrey, fontSize: 14)),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
