/// Commute Search Provider
///
/// Manages commute search/filter operations.
/// BACKEND BLOCKER: GET /commutes/search is MISSING.
/// Stubbed with GET /commutes/my as placeholder.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';
import '../providers/auth_provider.dart';
import '../providers/commute_provider.dart';

// =============================================================================
// STATE
// =============================================================================

class SearchFilters {
  final String? origin;
  final String? destination;
  final String? date;

  const SearchFilters({this.origin, this.destination, this.date});

  SearchFilters copyWith({
    String? origin,
    String? destination,
    String? date,
  }) {
    return SearchFilters(
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      date: date ?? this.date,
    );
  }
}

class CommuteSearchState {
  final List<Commute> results;
  final bool isLoading;
  final SearchFilters filters;

  const CommuteSearchState({
    this.results = const [],
    this.isLoading = false,
    this.filters = const SearchFilters(),
  });

  CommuteSearchState copyWith({
    List<Commute>? results,
    bool? isLoading,
    SearchFilters? filters,
  }) {
    return CommuteSearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      filters: filters ?? this.filters,
    );
  }
}

// =============================================================================
// NOTIFIER
// =============================================================================

class CommuteSearchNotifier extends Notifier<CommuteSearchState> {
  late final Dio _dio;

  @override
  CommuteSearchState build() {
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
    return const CommuteSearchState();
  }

  void _handle401() {
    ref.read(authProvider.notifier).logout();
  }

  // TODO: BACKEND BLOCKER — GET /commutes/search does not exist.
  // Using GET /commutes/my as placeholder until search endpoint is built.
  Future<void> search(SearchFilters filters) async {
    state = state.copyWith(isLoading: true, filters: filters);
    try {
      // PLACEHOLDER: Using /commutes/my instead of /commutes/search
      final response = await _dio.get('/api/v1/commutes/my');
      final List<dynamic> data = response.data as List;
      var commutes = data.map((j) => Commute.fromJson(j)).toList();

      // Client-side filtering as best-effort placeholder
      if (filters.origin != null && filters.origin!.isNotEmpty) {
        commutes = commutes
            .where((c) => c.originAddress
                .toLowerCase()
                .contains(filters.origin!.toLowerCase()))
            .toList();
      }
      if (filters.destination != null && filters.destination!.isNotEmpty) {
        commutes = commutes
            .where((c) => c.destinationAddress
                .toLowerCase()
                .contains(filters.destination!.toLowerCase()))
            .toList();
      }

      state = state.copyWith(results: commutes, isLoading: false);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _handle401();
        return;
      }
      state = state.copyWith(isLoading: false);
    }
  }

  void clearResults() {
    state = const CommuteSearchState();
  }
}

// =============================================================================
// PROVIDER
// =============================================================================

final commuteSearchProvider = NotifierProvider<CommuteSearchNotifier,
    CommuteSearchState>(CommuteSearchNotifier.new);
