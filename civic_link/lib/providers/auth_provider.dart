/// Auth State Management
///
/// Riverpod provider for authentication state.
/// Shares auth data (userId, token) between LoginScreen and DashboardScreen.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../main.dart';

// =============================================================================
// AUTH STATE MODEL
// =============================================================================

/// Immutable authentication state.
class AuthState {
  final String? userId;
  final String? accessToken;
  final String? refreshToken;
  final bool isAuthenticated;

  const AuthState({
    this.userId,
    this.accessToken,
    this.refreshToken,
    this.isAuthenticated = false,
  });

  factory AuthState.unauthenticated() {
    return const AuthState(isAuthenticated: false);
  }

  AuthState copyWith({
    String? userId,
    String? accessToken,
    String? refreshToken,
    bool? isAuthenticated,
  }) {
    return AuthState(
      userId: userId ?? this.userId,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

// =============================================================================
// AUTH NOTIFIER
// =============================================================================

class AuthNotifier extends Notifier<AuthState> {
  late final AuthService _authService;

  @override
  AuthState build() {
    _authService = ref.watch(authServiceProvider);
    AuthService.onUnauthorized = _handleUnauthorized;
    return AuthState.unauthenticated();
  }

  void _handleUnauthorized() {
    state = AuthState.unauthenticated();
  }

  Future<AuthResult<LoginResponse>> login(String email, String password) async {
    final result = await _authService.login(email, password);
    if (result.isSuccess && result.data != null) {
      final token = result.data!.accessToken;
      final refreshToken = result.data!.refreshToken;
      final userId = await _authService.getUserId();
      state = state.copyWith(
        userId: userId ?? 'unknown',
        accessToken: token,
        refreshToken: refreshToken,
        isAuthenticated: true,
      );
    }
    return result;
  }

  Future<AuthResult<RegisterResponse>> register({
    required String email,
    required String password,
    required String phoneNumber,
    required String fullName,
    required String gender,
    required String companyName,
    required String employeeId,
  }) async {
    final result = await _authService.register(
      rawEmail: email,
      password: password,
      phoneNumber: phoneNumber,
      fullName: fullName,
      gender: gender,
      companyName: companyName,
      employeeId: employeeId,
    );
    if (result.isSuccess && result.data != null) {
      state = state.copyWith(
        userId: result.data!.userId,
        isAuthenticated: false,
      );
    }
    return result;
  }

  Future<void> restoreSession() async {
    final token = await _authService.getAccessToken();
    final userId = await _authService.getUserId();
    final refreshToken = await _authService.getRefreshToken();

    if (token != null && userId != null) {
      state = state.copyWith(
        userId: userId,
        accessToken: token,
        refreshToken: refreshToken,
        isAuthenticated: true,
      );
      return;
    }

    // Access token expired but refresh token exists — attempt refresh
    if (refreshToken != null && userId != null) {
      final newToken = await _authService.refreshToken();
      if (newToken != null) {
        final newRefresh = await _authService.getRefreshToken();
        state = state.copyWith(
          userId: userId,
          accessToken: newToken,
          refreshToken: newRefresh,
          isAuthenticated: true,
        );
        return;
      }
    }

    state = AuthState.unauthenticated();
  }

  Future<bool> checkSessionValidity() async {
    return _authService.checkSessionValidity();
  }

  Future<void> logout() async {
    await _authService.logout();
    state = AuthState.unauthenticated();
  }
}

// =============================================================================
// PROVIDERS
// =============================================================================

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(baseUrl: kBaseUrl);
});

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
