/// Gradient progress ring with neon glow for the dashboard civic score.
///
/// Replaces the previous 6px flat linear bar with a more readable radial
/// gauge. Uses [CustomPainter] for full control of stroke caps + sweep.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_decoration.dart';
import '../../core/design/app_text_styles.dart';

class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.score,
    this.size = 240,
    this.strokeWidth = 14,
    this.animate = true,
    this.heroAnimationDuration = const Duration(milliseconds: 700),
  });

  /// Civic score 0..100.
  final double score;

  /// Outer diameter of the ring.
  final double size;

  /// Stroke thickness.
  final double strokeWidth;

  /// Whether to animate the score-in transition.
  final bool animate;

  /// Entrance animation duration.
  final Duration heroAnimationDuration;

  Color get _scoreColor => scoreTierColor(score);

  @override
  Widget build(BuildContext context) {
    final content = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ---- Glow behind the ring --------------------------------------
          Container(
            width: size * 0.85,
            height: size * 0.85,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: AppShadows.scoreGlow(_scoreColor),
            ),
          ),

          // ---- Ring --------------------------------------------------------
          CustomPaint(
            size: Size(size, size),
            painter: _ScoreRingPainter(
              score: score,
              color: _scoreColor,
              backgroundColor:
                  context.colors.surfaceContainerHighest.withValues(alpha: 0.4),
              strokeWidth: strokeWidth,
            ),
          ),

          // ---- Centre content ----------------------------------------------
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.toStringAsFixed(1),
                style: scoreHeroNumber(_scoreColor),
              ),
              const SizedBox(height: 6),
              Text(
                scoreTierLabel(score),
                style: scoreStatusLabel(_scoreColor),
              ),
            ],
          ),
        ],
      ),
    );

    if (!animate) return content;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: score),
      duration: heroAnimationDuration,
      curve: Curves.easeOutCubic,
      builder: (_, animatedScore, __) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size * 0.85,
              height: size * 0.85,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: AppShadows.scoreGlow(
                  scoreTierColor(animatedScore),
                ),
              ),
            ),
            CustomPaint(
              size: Size(size, size),
              painter: _ScoreRingPainter(
                score: animatedScore,
                color: scoreTierColor(animatedScore),
                backgroundColor: context
                    .colors.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                strokeWidth: strokeWidth,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  animatedScore.toStringAsFixed(1),
                  style: scoreHeroNumber(scoreTierColor(animatedScore)),
                ),
                const SizedBox(height: 6),
                Text(
                  scoreTierLabel(animatedScore),
                  style: scoreStatusLabel(scoreTierColor(animatedScore)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// PAINTER
// =============================================================================

class _ScoreRingPainter extends CustomPainter {
  const _ScoreRingPainter({
    required this.score,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  final double score;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  static const _startAngle = -math.pi / 2; // start at top

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background track
    final trackPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);

    // Progress arc with gradient sweep
    final sweepAngle = math.pi * 2 * (score.clamp(0.0, 100.0) / 100.0);
    if (sweepAngle <= 0) return;

    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: sweepAngle,
      colors: [color.withValues(alpha: 0.4), color],
      stops: const [0.0, 1.0],
      transform: GradientRotation(_startAngle),
    );

    final progressPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, _startAngle, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(_ScoreRingPainter oldDelegate) =>
      oldDelegate.score != score ||
      oldDelegate.color != color ||
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
