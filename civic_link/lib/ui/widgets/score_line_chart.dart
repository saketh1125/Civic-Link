/// Shared civic-score line chart.
///
/// Extracted from the duplicated `_buildLineChart` implementations previously
/// in dashboard_screen.dart and profile_screen.dart. One styling, two sizes.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_decoration.dart';

class ScoreLineChart extends StatelessWidget {
  const ScoreLineChart({
    super.key,
    required this.history,
    this.showAxisLabels = true,
    this.minY = 0,
    this.maxY = 100,
  });

  /// Scores, newest-first (reversed internally so time flows left→right).
  final List<double> history;

  /// Whether to show the 0/50/100 Y-axis labels (dashboard style) or hide
  /// them entirely (profile mini-chart style).
  final bool showAxisLabels;

  final double minY;
  final double maxY;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final spots = history.reversed
        .toList()
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    if (spots.isEmpty) {
      return Center(
        child: Text(
          'COLLECTING DATA...',
          style: context.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            letterSpacing: 1.0,
          ),
        ),
      );
    }

    final lineColor =
        spots.isNotEmpty ? scoreTierColor(spots.last.y) : scheme.primary;

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: showAxisLabels,
              reservedSize: 32,
              interval: 50,
              getTitlesWidget: (value, meta) {
                if (value == minY ||
                    value == (minY + maxY) / 2 ||
                    value == maxY) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      value.toInt().toString(),
                      style: context.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: lineColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  lineColor.withValues(alpha: 0.3),
                  lineColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: const LineTouchData(enabled: false),
      ),
    );
  }
}
