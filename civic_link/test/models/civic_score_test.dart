import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:civic_link/providers/civic_score_provider.dart';

void main() {
  group('CivicScoreState', () {
    test('initial state has score 100 and empty history', () {
      final state = CivicScoreState.initial();

      expect(state.currentScore, 100.0);
      expect(state.scoreHistory, isEmpty);
    });

    group('scoreColor', () {
      test('returns green for score >= 90', () {
        expect(
            CivicScoreState(currentScore: 100.0, scoreHistory: [])
                .scoreColor,
            kCivicScoreGreen);
        expect(
            CivicScoreState(currentScore: 90.0, scoreHistory: [])
                .scoreColor,
            kCivicScoreGreen);
      });

      test('returns yellow for score >= 70 and < 90', () {
        expect(
            CivicScoreState(currentScore: 89.9, scoreHistory: [])
                .scoreColor,
            kCivicScoreYellow);
        expect(
            CivicScoreState(currentScore: 70.0, scoreHistory: [])
                .scoreColor,
            kCivicScoreYellow);
      });

      test('returns red for score < 70', () {
        expect(
            CivicScoreState(currentScore: 69.9, scoreHistory: [])
                .scoreColor,
            kCivicScoreRed);
        expect(
            CivicScoreState(currentScore: 0.0, scoreHistory: [])
                .scoreColor,
            kCivicScoreRed);
      });
    });

    group('scoreStatus', () {
      test('returns CRUISING for score >= 90', () {
        expect(
          CivicScoreState(currentScore: 100.0, scoreHistory: []).scoreStatus,
          'CRUISING',
        );
        expect(
          CivicScoreState(currentScore: 90.0, scoreHistory: []).scoreStatus,
          'CRUISING',
        );
      });

      test('returns WARNING for score >= 70 and < 90', () {
        expect(
          CivicScoreState(currentScore: 89.9, scoreHistory: []).scoreStatus,
          'WARNING',
        );
        expect(
          CivicScoreState(currentScore: 70.0, scoreHistory: []).scoreStatus,
          'WARNING',
        );
      });

      test('returns ALERT for score < 70', () {
        expect(
          CivicScoreState(currentScore: 69.9, scoreHistory: []).scoreStatus,
          'ALERT',
        );
        expect(
          CivicScoreState(currentScore: 0.0, scoreHistory: []).scoreStatus,
          'ALERT',
        );
      });
    });

    group('score formatting', () {
      test('toStringAsFixed(1) formats score with one decimal', () {
        const state = CivicScoreState(currentScore: 85.0, scoreHistory: []);
        expect(state.currentScore.toStringAsFixed(1), '85.0');
      });

      test('score with many decimals is stored as-is', () {
        final state = CivicScoreState(
          currentScore: 85.6789,
          scoreHistory: [],
        );
        expect(state.currentScore, 85.6789);
        expect(state.currentScore.toStringAsFixed(1), '85.7');
      });
    });

    group('copyWith', () {
      test('creates a copy with updated score', () {
        final original =
            CivicScoreState(currentScore: 80.0, scoreHistory: []);
        final copy = original.copyWith(currentScore: 95.0);

        expect(copy.currentScore, 95.0);
        expect(copy.scoreHistory, isEmpty);
      });

      test('creates a copy with updated history', () {
        final original =
            CivicScoreState(currentScore: 80.0, scoreHistory: [80.0]);
        final copy = original.copyWith(scoreHistory: [90.0, 85.0]);

        expect(copy.currentScore, 80.0);
        expect(copy.scoreHistory, [90.0, 85.0]);
      });
    });
  });

  group('CivicScoreNotifier', () {
    test('initial state via provider', () {
      final container = ProviderContainer();
      final state = container.read(civicScoreProvider);
      expect(state.currentScore, 100.0);
      expect(state.scoreHistory, isEmpty);
      container.dispose();
    });

    test('updateScore clamps to 0-100 range', () {
      final container = ProviderContainer();
      final notifier = container.read(civicScoreProvider.notifier);

      notifier.updateScore(150.0);
      expect(container.read(civicScoreProvider).currentScore, 100.0);

      notifier.updateScore(-50.0);
      expect(container.read(civicScoreProvider).currentScore, 0.0);

      container.dispose();
    });

    test('updateScore adds to history', () {
      final container = ProviderContainer();
      final notifier = container.read(civicScoreProvider.notifier);

      notifier.updateScore(85.0);
      expect(container.read(civicScoreProvider).scoreHistory, [85.0]);

      notifier.updateScore(90.0);
      expect(container.read(civicScoreProvider).scoreHistory, [90.0, 85.0]);

      container.dispose();
    });

    test('updateScore caps history at maxHistoryLength', () {
      final container = ProviderContainer();
      final notifier = container.read(civicScoreProvider.notifier);

      for (int i = 0; i < 25; i++) {
        notifier.updateScore(100.0 - i.toDouble());
      }

      final state = container.read(civicScoreProvider);
      expect(
          state.scoreHistory.length, CivicScoreNotifier.maxHistoryLength);
      expect(state.scoreHistory.last, 95.0);
      expect(state.scoreHistory.first, 76.0);

      container.dispose();
    });

    test('reset clears state to initial', () {
      final container = ProviderContainer();
      final notifier = container.read(civicScoreProvider.notifier);

      notifier.updateScore(50.0);
      notifier.reset();

      final state = container.read(civicScoreProvider);
      expect(state.currentScore, 100.0);
      expect(state.scoreHistory, isEmpty);

      container.dispose();
    });

    test('setHistory replaces current state', () {
      final container = ProviderContainer();
      final notifier = container.read(civicScoreProvider.notifier);

      notifier.setHistory([70.0, 80.0, 90.0]);

      final state = container.read(civicScoreProvider);
      expect(state.currentScore, 90.0);
      expect(state.scoreHistory, [90.0, 80.0, 70.0]);

      container.dispose();
    });

    test('setHistory with empty list resets', () {
      final container = ProviderContainer();
      final notifier = container.read(civicScoreProvider.notifier);

      notifier.updateScore(50.0);
      notifier.setHistory([]);

      final state = container.read(civicScoreProvider);
      expect(state.currentScore, 100.0);
      expect(state.scoreHistory, isEmpty);

      container.dispose();
    });

    test('setHistory truncates to maxHistoryLength', () {
      final container = ProviderContainer();
      final notifier = container.read(civicScoreProvider.notifier);

      final longHistory = List<double>.generate(30, (i) => i.toDouble());
      notifier.setHistory(longHistory);

      final state = container.read(civicScoreProvider);
      expect(
          state.scoreHistory.length, CivicScoreNotifier.maxHistoryLength);
      expect(state.currentScore, 29.0);

      container.dispose();
    });
  });
}
