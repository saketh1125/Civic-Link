/// Civic Score State Management
///
/// Provides real-time Civic Score tracking with a 20-item history buffer
/// for chart visualization. TelemetryService lifecycle is managed inside
/// the notifier — start/stop via exposed methods, auto-cleanup on dispose.
///
/// Usage:
/// ```dart
/// final scoreState = ref.watch(civicScoreProvider);
/// final notifier = ref.read(civicScoreProvider.notifier);
///
/// // Start the 50Hz telemetry engine (call after login):
/// await notifier.startTelemetry(
///   baseUrl: kBaseUrl,
///   userId: userId,
///   authToken: token,
/// );
/// ```

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/telemetry_isolate.dart';

// =============================================================================
// COLOR CONSTANTS - High-contrast law enforcement palette
// =============================================================================

/// Neon Green - Safe/Cruising state (score >= 90)
const Color kCivicScoreGreen = Color(0xFF00E676);

/// Warning Yellow - Caution state (score >= 70, < 90)
const Color kCivicScoreYellow = Color(0xFFFFEA00);

/// Alert Red - Danger state (score < 70)
const Color kCivicScoreRed = Color(0xFFFF1744);

/// Deep Black - Dashboard background
const Color kDashboardBackground = Color(0xFF0A0A0A);

// =============================================================================
// STATE MODEL
// =============================================================================

/// Immutable state container for Civic Score data.
class CivicScoreState {
  final double currentScore;
  final List<double> scoreHistory;

  const CivicScoreState({
    required this.currentScore,
    required this.scoreHistory,
  });

  /// Factory constructor for initial state.
  factory CivicScoreState.initial() {
    return const CivicScoreState(
      currentScore: 100.0,
      scoreHistory: [],
    );
  }

  /// Returns the color based on current score threshold.
  Color get scoreColor {
    if (currentScore >= 90.0) {
      return kCivicScoreGreen;
    } else if (currentScore >= 70.0) {
      return kCivicScoreYellow;
    } else {
      return kCivicScoreRed;
    }
  }

  /// Returns the status label based on current score threshold.
  String get scoreStatus {
    if (currentScore >= 90.0) {
      return 'CRUISING';
    } else if (currentScore >= 70.0) {
      return 'WARNING';
    } else {
      return 'ALERT';
    }
  }

  /// Creates a copy with optionally updated fields.
  CivicScoreState copyWith({
    double? currentScore,
    List<double>? scoreHistory,
  }) {
    return CivicScoreState(
      currentScore: currentScore ?? this.currentScore,
      scoreHistory: scoreHistory ?? this.scoreHistory,
    );
  }
}

// =============================================================================
// STATE NOTIFIER
// =============================================================================

/// Manages Civic Score state with a 20-item circular buffer,
/// plus the lifecycle of the 50Hz TelemetryService isolate.
///
/// This notifier maintains the current score and a rolling history
/// for the real-time chart. The history is capped at 20 items
/// to maintain consistent chart density and memory efficiency.
class CivicScoreNotifier extends Notifier<CivicScoreState> {
  /// Maximum number of historical scores to retain.
  static const int maxHistoryLength = 20;

  TelemetryService? _telemetryService;

  @override
  CivicScoreState build() {
    ref.onDispose(() {
      _telemetryService?.stop();
      _telemetryService = null;
    });
    return CivicScoreState.initial();
  }

  /// Starts the background telemetry isolate.
  ///
  /// Spawns an isolate that reads IMU sensors at 50Hz, computes
  /// the Civic Score, and sends updates back to this notifier
  /// via [onScoreUpdate] → [updateScore].
  Future<void> startTelemetry({
    required String baseUrl,
    required String userId,
    required String authToken,
    String? matchId,
  }) async {
    await stopTelemetry();
    _telemetryService = TelemetryService(
      baseUrl: baseUrl,
      userId: userId,
      matchId: matchId,
      authToken: authToken,
      onScoreUpdate: updateScore,
    );
    _telemetryService!.statusStream.listen(_handleTelemetryStatus);
    await _telemetryService!.start();
  }

  /// Handles telemetry status messages from the isolate.
  void _handleTelemetryStatus(TelemetryStatus status) {
    if (status is ScoreUpdate) {
      updateScore(status.score);
    } else if (status is ScoreIngested) {
      updateScore(status.civicScore);
    }
  }

  /// Triggers score ingestion to the backend /ingest endpoint.
  ///
  /// Transforms the current IMU buffer into weighted-penalty samples
  /// and POSTs them for server-side score calculation.
  Future<void> refreshScore({
    required String tripId,
  }) async {
    if (_telemetryService == null || !_telemetryService!.isRunning) return;
    await _telemetryService!.ingestScore(
      tripId: tripId,
      samples: [],
    );
  }

  /// Stops the isolate and releases resources.
  Future<void> stopTelemetry() async {
    await _telemetryService?.stop();
    _telemetryService = null;
  }

  /// Updates the current score and adds it to history.
  ///
  /// [newScore] - The new Civic Score value (0.0 to 100.0)
  ///
  /// The new score becomes the current score and is prepended
  /// to the history list. If history exceeds 20 items, the oldest
  /// score is dropped (FIFO eviction).
  void updateScore(double newScore) {
    final clampedScore = newScore.clamp(0.0, 100.0);
    final newHistory = [clampedScore, ...state.scoreHistory];

    if (newHistory.length > maxHistoryLength) {
      newHistory.removeLast();
    }

    state = state.copyWith(
      currentScore: clampedScore,
      scoreHistory: newHistory,
    );
  }

  /// Resets the score to perfect and clears history.
  void reset() {
    state = CivicScoreState.initial();
  }

  /// Batch update for replaying historical data.
  void setHistory(List<double> scores) {
    if (scores.isEmpty) {
      reset();
      return;
    }

    final truncated = scores.length > maxHistoryLength
        ? scores.sublist(scores.length - maxHistoryLength)
        : List<double>.from(scores);

    state = state.copyWith(
      currentScore: truncated.last,
      scoreHistory: truncated.reversed.toList(),
    );
  }
}

// =============================================================================
// PROVIDER EXPORTS
// =============================================================================

/// Global provider for Civic Score state.
///
/// Access via:
/// - `ref.watch(civicScoreProvider)` to listen to state changes
/// - `ref.read(civicScoreProvider.notifier)` to call updateScore()
final civicScoreProvider =
    NotifierProvider<CivicScoreNotifier, CivicScoreState>(CivicScoreNotifier.new);
