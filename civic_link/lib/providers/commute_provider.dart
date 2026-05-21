/// Commute Provider
///
/// Manages commute CRUD operations. Depends on authProvider for JWT token.
/// Uses AsyncNotifier pattern.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';
import '../providers/auth_provider.dart';

// =============================================================================
// MODELS
// =============================================================================

class Commute {
  final String id;
  final String driverId;
  final String originAddress;
  final String destinationAddress;
  final String departureDate;
  final String departureTime;
  final int availableSeats;
  final int totalSeats;
  final bool isWomenOnly;
  final String commuteType;
  final String status;

  const Commute({
    required this.id,
    required this.driverId,
    required this.originAddress,
    required this.destinationAddress,
    required this.departureDate,
    required this.departureTime,
    required this.availableSeats,
    required this.totalSeats,
    required this.isWomenOnly,
    required this.commuteType,
    required this.status,
  });

  factory Commute.fromJson(Map<String, dynamic> json) {
    return Commute(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      originAddress: json['origin_address'] as String,
      destinationAddress: json['destination_address'] as String,
      departureDate: json['departure_date'] as String,
      departureTime: json['departure_time'] as String,
      availableSeats: json['available_seats'] as int,
      totalSeats: json['total_seats'] as int,
      isWomenOnly: json['is_women_only'] as bool,
      commuteType: json['commute_type'] as String,
      status: json['status'] as String,
    );
  }
}

class CommuteDetail extends Commute {
  final String driverName;
  final String driverGender;
  final double? driverScore;

  const CommuteDetail({
    required super.id,
    required super.driverId,
    required super.originAddress,
    required super.destinationAddress,
    required super.departureDate,
    required super.departureTime,
    required super.availableSeats,
    required super.totalSeats,
    required super.isWomenOnly,
    required super.commuteType,
    required super.status,
    required this.driverName,
    required this.driverGender,
    this.driverScore,
  });

  factory CommuteDetail.fromJson(Map<String, dynamic> json) {
    return CommuteDetail(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      originAddress: json['origin_address'] as String,
      destinationAddress: json['destination_address'] as String,
      departureDate: json['departure_date'] as String,
      departureTime: json['departure_time'] as String,
      availableSeats: json['available_seats'] as int,
      totalSeats: json['total_seats'] as int,
      isWomenOnly: json['is_women_only'] as bool,
      commuteType: json['commute_type'] as String,
      status: json['status'] as String,
      driverName: json['driver_name'] as String? ?? 'Unknown',
      driverGender: json['driver_gender'] as String? ?? 'unknown',
      driverScore: (json['driver_score'] as num?)?.toDouble(),
    );
  }
}

// =============================================================================
// STATE
// =============================================================================

class CommuteOffer {
  final String id;
  final String passengerId;
  final String originAddress;
  final String destinationAddress;
  final String preferredDepartureDate;
  final String preferredDepartureTime;
  final bool isWomenOnly;
  final int maxWalkingDistance;
  final String status;

  const CommuteOffer({
    required this.id,
    required this.passengerId,
    required this.originAddress,
    required this.destinationAddress,
    required this.preferredDepartureDate,
    required this.preferredDepartureTime,
    required this.isWomenOnly,
    required this.maxWalkingDistance,
    required this.status,
  });

  factory CommuteOffer.fromJson(Map<String, dynamic> json) {
    return CommuteOffer(
      id: json['id'] as String,
      passengerId: json['passenger_id'] as String,
      originAddress: json['origin_address'] as String,
      destinationAddress: json['destination_address'] as String,
      preferredDepartureDate: json['preferred_departure_date'] as String,
      preferredDepartureTime: json['preferred_departure_time'] as String,
      isWomenOnly: json['is_women_only'] as bool,
      maxWalkingDistance: json['max_walking_distance'] as int,
      status: json['status'] as String,
    );
  }
}

class CommuteState {
  final List<Commute> commutes;
  final List<CommuteOffer> offers;
  final bool isLoading;
  final String? error;

  const CommuteState({
    this.commutes = const [],
    this.offers = const [],
    this.isLoading = false,
    this.error,
  });

  CommuteState copyWith({
    List<Commute>? commutes,
    List<CommuteOffer>? offers,
    bool? isLoading,
    String? error,
  }) {
    return CommuteState(
      commutes: commutes ?? this.commutes,
      offers: offers ?? this.offers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// =============================================================================
// NOTIFIER
// =============================================================================

class CommuteNotifier extends Notifier<CommuteState> {
  late final Dio _dio;

  @override
  CommuteState build() {
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
    return const CommuteState();
  }

  void _handle401() {
    ref.read(authProvider.notifier).logout();
  }

  Future<void> fetchMyCommutes() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.get('/api/v1/commutes/my');
      final List<dynamic> data = response.data as List;
      final commutes = data.map((j) => Commute.fromJson(j)).toList();
      state = state.copyWith(commutes: commutes, isLoading: false);
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

  Future<void> fetchMyOffers() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.get('/api/v1/commutes/offers/my');
      final List<dynamic> data = response.data as List;
      final offers = data.map((j) => CommuteOffer.fromJson(j)).toList();
      state = state.copyWith(offers: offers, isLoading: false);
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

  Future<CommuteDetail?> fetchCommuteDetail(String id) async {
    try {
      final response = await _dio.get('/api/v1/commutes/$id');
      return CommuteDetail.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _handle401();
        return null;
      }
      state = state.copyWith(error: _extractError(e));
      return null;
    }
  }

  /// Geocode an address to lat/lon using Nominatim (free, no API key).
  /// Returns [lat, lon] or null if not found.
  Future<List<double>?> geocodeAddress(String address) async {
    try {
      final response = await Dio().get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': address,
          'format': 'json',
          'limit': 1,
        },
        options: Options(headers: {
          'User-Agent': 'civic-link/1.0 (carpooling app)',
        }),
      );
      final List data = response.data;
      if (data.isEmpty) return null;
      final lat = double.parse(data[0]['lat']);
      final lon = double.parse(data[0]['lon']);
      return [lat, lon];
    } catch (_) {
      return null;
    }
  }

  Future<bool> createCommute({
    required String originAddress,
    required String destinationAddress,
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
    required String departureDate,
    required String departureTime,
    required int availableSeats,
    required int totalSeats,
    required bool isWomenOnly,
    String commuteType = 'one_time',
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _dio.post('/api/v1/commutes', data: {
        'origin_lat': originLat,
        'origin_lon': originLon,
        'destination_lat': destLat,
        'destination_lon': destLon,
        'origin_address': originAddress,
        'destination_address': destinationAddress,
        'departure_date': departureDate,
        'departure_time': departureTime,
        'available_seats': availableSeats,
        'total_seats': totalSeats,
        'is_women_only': isWomenOnly,
        'commute_type': commuteType,
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

  Future<bool> cancelCommute(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _dio.post('/api/v1/commutes/$id/cancel');
      await fetchMyCommutes();
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

final commuteProvider =
    NotifierProvider<CommuteNotifier, CommuteState>(CommuteNotifier.new);
