/// Rating Screen
///
/// Redesigned with animated star selection, glowing visual feedback,
/// and a polished submit flow.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_decoration.dart';
import '../../core/design/app_spacing.dart';
import '../../providers/match_provider.dart';
import '../widgets/auth_guard.dart';
import '../widgets/error_banner.dart';
import '../widgets/glass_card.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/neon_button.dart';

class RatingScreen extends ConsumerStatefulWidget {
  final String matchId;

  const RatingScreen({super.key, required this.matchId});

  @override
  ConsumerState<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends ConsumerState<RatingScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();

  static const _ratingLabels = {
    5: 'Perfect',
    4: 'Great',
    3: 'Okay',
    2: 'Poor',
    1: 'Terrible',
  };

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  static Color get _starColor => kScoreWarning;

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    final success = await ref.read(matchProvider.notifier).rateMatch(
          matchId: widget.matchId,
          rating: _rating,
          comment: _commentController.text.trim(),
        );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Thanks for rating!'),
          backgroundColor: context.colors.primary,
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchState = ref.watch(matchProvider);
    final scheme = context.colors;

    return AuthGuard(
      child: LoadingOverlay(
        isLoading: matchState.isLoading,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('RATE MATCH'),
            leading: const BackButton(),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              children: [
                const Gap(16),

                // ---- Card container -----------------------------------------
                GlassCard(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      // Animated icon
                      AnimatedContainer(
                        duration: AppMotion.medium,
                        curve: AppMotion.standard,
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _starColor
                              .withValues(alpha: _rating > 0 ? 0.15 : 0.08),
                          border: Border.all(
                            color: _rating > 0
                                ? _starColor
                                : scheme.onSurfaceVariant,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          _rating > 0
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color:
                              _rating > 0 ? _starColor : scheme.onSurfaceVariant,
                          size: 36,
                        ),
                      ),
                      const Gap(24),

                      Text(
                        'How was your experience?',
                        style: context.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const Gap(8),
                      Text(
                        _ratingLabels[_rating] ??
                            'Your rating helps improve the platform',
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: _rating > 0
                              ? _starColor
                              : scheme.onSurfaceVariant,
                          fontWeight:
                              _rating > 0 ? FontWeight.w600 : FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Gap(28),

                      // ---- Animated stars -------------------------------------
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final starNum = index + 1;
                          final isSelected = starNum <= _rating;
                          return _AnimatedStar(
                            isSelected: isSelected,
                            size: 44,
                            color: _starColor,
                            onTap: () => setState(() => _rating = starNum),
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                const Gap(24),

                // ---- Comment --------------------------------------------------
                TextField(
                  controller: _commentController,
                  maxLines: 4,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: 'Add a comment (optional)...',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                ),

                // ---- Error banner ----------------------------------------------
                if (matchState.error != null) ...[
                  const Gap(16),
                  ErrorBanner(
                    message: matchState.error!,
                  ),
                ],

                const Gap(24),

                // ---- Submit -----------------------------------------------------
                NeonButton(
                  label: 'SUBMIT RATING',
                  icon: Icons.star_rounded,
                  isLoading: matchState.isLoading,
                  onPressed: _submitRating,
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
// ANIMATED STAR
// =============================================================================

class _AnimatedStar extends StatefulWidget {
  const _AnimatedStar({
    required this.isSelected,
    required this.size,
    required this.color,
    required this.onTap,
  });

  final bool isSelected;
  final double size;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_AnimatedStar> createState() => _AnimatedStarState();
}

class _AnimatedStarState extends State<_AnimatedStar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }

  @override
  void didUpdateWidget(covariant _AnimatedStar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : const [],
            ),
            child: Icon(
              widget.isSelected
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              color: widget.isSelected
                  ? widget.color
                  : Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.5),
              size: widget.size,
            ),
          ),
        ),
      ),
    );
  }
}
