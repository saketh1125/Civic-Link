/// Profile Provider
///
/// Manages user profile state. Depends on authProvider for JWT token.
/// Uses Notifier pattern (consistent with existing providers).

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';
import '../providers/auth_provider.dart';

// =============================================================================
// STATE
// =============================================================================

class ProfileState {
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final String? name;
  final String? email;
  final String? phoneNumber;
  final String? verificationStatus;
  final String? gender;
  final String? companyName;

  const ProfileState({
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.name,
    this.email,
    this.phoneNumber,
    this.verificationStatus,
    this.gender,
    this.companyName,
  });

  ProfileState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? error,
    String? name,
    String? email,
    String? phoneNumber,
    String? verificationStatus,
    String? gender,
    String? companyName,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: error,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      gender: gender ?? this.gender,
      companyName: companyName ?? this.companyName,
    );
  }
}

// =============================================================================
// NOTIFIER
// =============================================================================

class ProfileNotifier extends Notifier<ProfileState> {
  late final Dio _dio;

  @override
  ProfileState build() {
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
    return const ProfileState();
  }

  void _handle401() {
    ref.read(authProvider.notifier).logout();
  }

  /// Load profile from GET /auth/me.
  /// Falls back to authProvider state if endpoint fails.
  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.get('/api/v1/auth/me');
      final data = response.data as Map<String, dynamic>;
      state = state.copyWith(
        isLoading: false,
        name: data['full_name'] as String?,
        email: data['email_domain'] as String?,
        verificationStatus: data['is_verified'] == true ? 'verified' : 'pending',
        gender: data['gender'] as String?,
        companyName: data['company_name'] as String?,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _handle401();
        return;
      }
      // Fallback: use authProvider state
      final authState = ref.read(authProvider);
      state = state.copyWith(
        isLoading: false,
        name: authState.userId ?? 'User',
        error: null, // Don't show error for fallback
      );
    }
  }

  /// Update profile via PUT /auth/me. Partial update — only sends changed fields.
  Future<bool> updateProfile({String? name, String? phoneNumber}) async {
    state = state.copyWith(isSaving: true, error: null);
    try {
      final Map<String, dynamic> data = {};
      if (name != null && name.isNotEmpty) data['full_name'] = name;
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        data['phone_number'] = phoneNumber;
      }

      if (data.isEmpty) {
        state = state.copyWith(isSaving: false);
        return true;
      }

      final response = await _dio.put('/api/v1/auth/me', data: data);
      final result = response.data as Map<String, dynamic>;
      state = state.copyWith(
        isSaving: false,
        name: result['full_name'] as String?,
        email: result['email_domain'] as String?,
        verificationStatus: result['is_verified'] == true ? 'verified' : 'pending',
        gender: result['gender'] as String?,
        companyName: result['company_name'] as String?,
      );
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _handle401();
        return false;
      }
      state = state.copyWith(
        isSaving: false,
        error: _extractError(e),
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
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

final profileProvider =
    NotifierProvider<ProfileNotifier, ProfileState>(ProfileNotifier.new);
