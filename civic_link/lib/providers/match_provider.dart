/// Match Provider
///
/// Manages match CRUD operations. Depends on authProvider for JWT token.
/// Uses AsyncNotifier pattern.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';
import '../providers/auth_provider.dart';

// =============================================================================
// MODELS
// =============================================================================

class Match {
  final String id;
  final String commuteId;
  final String driverId;
  final String passengerId;
  final String status;
  final int pickupRadiusMeters;
  final double? fareAmount;
  final String paymentStatus;
  final bool commuteWasWomenOnly;
  final bool offerWasWomenOnly;
  final String? confirmedAt;
  final String? startedAt;
  final String? completedAt;

  const Match({
    required this.id,
    required this.commuteId,
    required this.driverId,
    required this.passengerId,
    required this.status,
    required this.pickupRadiusMeters,
    this.fareAmount,
    required this.paymentStatus,
    required this.commuteWasWomenOnly,
    required this.offerWasWomenOnly,
    this.confirmedAt,
    this.startedAt,
    this.completedAt,
  });

  factory Match.fromJson(Map<String, dynamic> json) {
    return Match(
      id: json['id'] as String,
      commuteId: json['commute_id'] as String,
      driverId: json['driver_id'] as String,
      passengerId: json['passenger_id'] as String,
      status: json['status'] as String,
      pickupRadiusMeters: json['pickup_radius_meters'] as int,
      fareAmount: (json['fare_amount'] as num?)?.toDouble(),
      paymentStatus: json['payment_status'] as String,
      commuteWasWomenOnly: json['commute_was_women_only'] as bool,
      offerWasWomenOnly: json['offer_was_women_only'] as bool,
      confirmedAt: json['confirmed_at'] as String?,
      startedAt: json['started_at'] as String?,
      completedAt: json['completed_at'] as String?,
    );
  }
}

class MatchDetail extends Match {
  final String driverName;
  final String passengerName;
  final String originAddress;
  final String destinationAddress;

  const MatchDetail({
    required super.id,
    required super.commuteId,
    required super.driverId,
    required super.passengerId,
    required super.status,
    required super.pickupRadiusMeters,
    super.fareAmount,
    required super.paymentStatus,
    required super.commuteWasWomenOnly,
    required super.offerWasWomenOnly,
    super.confirmedAt,
    super.startedAt,
    super.completedAt,
    required this.driverName,
    required this.passengerName,
    required this.originAddress,
    required this.destinationAddress,
  });

  factory MatchDetail.fromJson(Map<String, dynamic> json) {
    return MatchDetail(
      id: json['id'] as String,
      commuteId: json['commute_id'] as String,
      driverId: json['driver_id'] as String,
      passengerId: json['passenger_id'] as String,
      status: json['status'] as String,
      pickupRadiusMeters: json['pickup_radius_meters'] as int,
      fareAmount: (json['fare_amount'] as num?)?.toDouble(),
      paymentStatus: json['payment_status'] as String,
      commuteWasWomenOnly: json['commute_was_women_only'] as bool,
      offerWasWomenOnly: json['offer_was_women_only'] as bool,
      confirmedAt: json['confirmed_at'] as String?,
      startedAt: json['started_at'] as String?,
      completedAt: json['completed_at'] as String?,
      driverName: json['driver_name'] as String? ?? 'Unknown',
      passengerName: json['passenger_name'] as String? ?? 'Unknown',
      originAddress: json['origin_address'] as String? ?? '',
      destinationAddress: json['destination_address'] as String? ?? '',
    );
  }
}

// =============================================================================
// STATE
// =============================================================================

class MatchState {
  final List<Match> matches;
  final bool isLoading;
  final String? error;

  const MatchState({
    this.matches = const [],
    this.isLoading = false,
    this.error,
  });

  MatchState copyWith({
    List<Match>? matches,
    bool? isLoading,
    String? error,
  }) {
    return MatchState(
      matches: matches ?? this.matches,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// =============================================================================
// NOTIFIER
// =============================================================================

class MatchNotifier extends Notifier<MatchState> {
  late final Dio _dio;

  @override
  MatchState build() {
    final authState = ref.read(authProvider);
    _dio = Dio(BaseOptions(
      baseUrl: kBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        if (authState.accessToken != null)
          'Authorization': 'Bearer ${authState.accessToken}',
      },
    ));
    return const MatchState();
  }

  void _handle401() {
    ref.read(authProvider.notifier).logout();
  }

  Future<void> fetchMyMatches() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.get('/api/v1/matches/my');
      final data = response.data;
      final List<dynamic> items = data['items'] ?? data;
      final matches = items.map((j) => Match.fromJson(j)).toList();
      state = state.copyWith(matches: matches, isLoading: false);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _handle401();
        return;
      }
      state = state.copyWith(
        isLoading: false,
        error: _extractError(e),
      );
    }
  }

  Future<MatchDetail?> fetchMatchDetail(String id) async {
    try {
      final response = await _dio.get('/api/v1/matches/$id');
      return MatchDetail.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _handle401();
        return null;
      }
      state = state.copyWith(error: _extractError(e));
      return null;
    }
  }

  Future<bool> requestMatch(String commuteId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _dio.post('/api/v1/matches/$commuteId/request');
      state = state.copyWith(isLoading: false);
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _handle401();
        return false;
      }
      state = state.copyWith(
        isLoading: false,
        error: _extractError(e),
      );
      return false;
    }
  }

  Future<bool> confirmMatch(String matchId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _dio.post('/api/v1/matches/$matchId/confirm');
      await fetchMyMatches();
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _handle401();
        return false;
      }
      state = state.copyWith(
        isLoading: false,
        error: _extractError(e),
      );
      return false;
    }
  }

  Future<bool> rateMatch({
    required String matchId,
    required int rating,
    String? comment,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _dio.post('/api/v1/matches/$matchId/rate', data: {
        'driver_rating': rating,
        if (comment != null && comment.isNotEmpty) 'driver_review': comment,
      });
      state = state.copyWith(isLoading: false);
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _handle401();
        return false;
      }
      state = state.copyWith(
        isLoading: false,
        error: _extractError(e),
      );
      return false;
    }
  }

  String _extractError(DioException e) {
    if (e.response?.data is Map && e.response!.data['detail'] != null) {
      return e.response!.data['detail'] as String;
    }
    return 'Something went wrong. Please try again.';
  }
}

// =============================================================================
// PROVIDER
// =============================================================================

final matchProvider =
    NotifierProvider<MatchNotifier, MatchState>(MatchNotifier.new);
