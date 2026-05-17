/// Rating Screen
///
/// Star rating widget (1-5 stars) with optional comment.
/// Submits rating and navigates to dashboard.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart';
import '../../providers/match_provider.dart';
import '../widgets/auth_guard.dart';
import '../widgets/error_banner.dart';
import '../widgets/loading_overlay.dart';

class RatingScreen extends ConsumerStatefulWidget {
  final String matchId;

  const RatingScreen({super.key, required this.matchId});

  @override
  ConsumerState<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends ConsumerState<RatingScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

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
        const SnackBar(
          content: Text('Thanks for rating!'),
          backgroundColor: Color(0xFF00E676),
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchState = ref.watch(matchProvider);

    return AuthGuard(
      child: LoadingOverlay(
        isLoading: matchState.isLoading,
        child: Scaffold(
          backgroundColor: kPrimaryBlack,
          appBar: AppBar(
            backgroundColor: kPrimaryBlack,
            elevation: 0,
            title: const Text(
              'RATE MATCH',
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
                const SizedBox(height: 20),

                // Title
                const Text(
                  'How was your experience?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your rating helps improve the platform',
                  style: TextStyle(color: kHintGrey, fontSize: 14),
                ),
                const SizedBox(height: 40),

                // Star rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starNum = index + 1;
                    final isSelected = starNum <= _rating;
                    return GestureDetector(
                      onTap: () => setState(() => _rating = starNum),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          isSelected ? Icons.star : Icons.star_border,
                          color: isSelected
                              ? const Color(0xFFFFEA00)
                              : kHintGrey,
                          size: 48,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Text(
                  _rating == 0
                      ? 'Tap to rate'
                      : '$_rating out of 5 stars',
                  style: TextStyle(
                    color: _rating > 0
                        ? const Color(0xFFFFEA00)
                        : kHintGrey,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 40),

                // Comment
                TextField(
                  controller: _commentController,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Add a comment (optional)...',
                    hintStyle: TextStyle(color: kHintGrey),
                    filled: true,
                    fillColor: kInputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Error
                if (matchState.error != null) ...[
                  ErrorBanner(message: matchState.error!),
                  const SizedBox(height: 16),
                ],

                // Submit
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: matchState.isLoading ? null : _submitRating,
                    child: const Text('SUBMIT RATING'),
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
