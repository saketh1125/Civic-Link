/// Real-Time Civic Score Dashboard
///
/// Professional law enforcement interface displaying the Civic Score
/// with animated transitions and a tactical line chart. Designed for
/// high-contrast visibility in vehicle-mounted devices.
///
/// Features:
/// - Massive central score display with 300ms lerp animation
/// - Color-coded thresholds (Green/Yellow/Red)
/// - Smooth spline chart showing 20-point history
/// - Deep black tactical aesthetic

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../providers/civic_score_provider.dart';
import '../../providers/auth_provider.dart';
import '../../main.dart';

// =============================================================================
// DASHBOARD SCREEN
// =============================================================================

/// Main dashboard screen for Civic Score monitoring.
///
/// Displays the current score with animated transitions and a
/// historical trend chart. Optimized for quick glances during patrol.
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

      final valid = await ref.read(authProvider.notifier).checkSessionValidity();
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
      backgroundColor: kDashboardBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Main Score Display (takes most space)
            Expanded(
              flex: 3,
              child: _buildScoreDisplay(scoreState),
            ),

            // Chart Section
            Expanded(
              flex: 2,
              child: _buildChartSection(scoreState),
            ),

            // Bottom padding for device mounts
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Builds the screen header with title.
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: kCivicScoreGreen,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'CIVIC SCORE',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the central animated score display.
  Widget _buildScoreDisplay(CivicScoreState scoreState) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated Score Number
          TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: scoreState.currentScore,
              end: scoreState.currentScore,
            ),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, child) {
              return Text(
                value.toStringAsFixed(1),
                style: TextStyle(
                  color: scoreState.scoreColor,
                  fontSize: 120,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'RobotoMono',
                  letterSpacing: -2,
                  shadows: [
                    Shadow(
                      color: scoreState.scoreColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          // Status Label
          Text(
            scoreState.scoreStatus,
            style: TextStyle(
              color: scoreState.scoreColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 3.0,
            ),
          ),

          const SizedBox(height: 24),

          // Score Bar Indicator
          _buildScoreBar(scoreState),
        ],
      ),
    );
  }

  /// Builds a horizontal bar indicator showing score position.
  Widget _buildScoreBar(CivicScoreState scoreState) {
    return Container(
      width: 200,
      height: 6,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: scoreState.currentScore / 100.0,
        child: Container(
          decoration: BoxDecoration(
            color: scoreState.scoreColor,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: scoreState.scoreColor.withOpacity(0.5),
                blurRadius: 8,
                offset: const Offset(0, 0),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the chart section with line chart.
  Widget _buildChartSection(CivicScoreState scoreState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart Label
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12),
            child: Text(
              'HISTORY',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ),

          // Chart Container
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: _buildLineChart(scoreState),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the fl_chart LineChart widget.
  Widget _buildLineChart(CivicScoreState scoreState) {
    // Convert history to FlSpot list (reversed for left-to-right timeline)
    final spots = scoreState.scoreHistory.reversed.toList().asMap().entries.map(
      (entry) {
        return FlSpot(entry.key.toDouble(), entry.value);
      },
    ).toList();

    // If no history, show empty state
    if (spots.isEmpty) {
      return Center(
        child: Text(
          'COLLECTING DATA...',
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 12,
            letterSpacing: 1.0,
          ),
        ),
      );
    }

    return LineChart(
      LineChartData(
        // Fixed Y-axis range: 0 to 100
        minY: 0,
        maxY: 100,

        // Grid configuration: completely hidden for tactical look
        gridData: const FlGridData(show: false),

        // Border configuration: minimal
        borderData: FlBorderData(show: false),

        // X-axis: hidden (no labels, no titles)
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 50,
              getTitlesWidget: (value, meta) {
                // Only show 0, 50, 100
                if (value == 0 || value == 50 || value == 100) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),

        // Chart line configuration
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: scoreState.scoreColor,
            barWidth: 3,
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

        // Interaction: disabled for read-only dashboard
        lineTouchData: const LineTouchData(enabled: false),
      ),
    );
  }
}
