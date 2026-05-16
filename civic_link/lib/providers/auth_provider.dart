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
  final bool isAuthenticated;

  const AuthState({
    this.userId,
    this.accessToken,
    this.isAuthenticated = false,
  });

  factory AuthState.unauthenticated() {
    return const AuthState(isAuthenticated: false);
  }

  AuthState copyWith({
    String? userId,
    String? accessToken,
    bool? isAuthenticated,
  }) {
    return AuthState(
      userId: userId ?? this.userId,
      accessToken: accessToken ?? this.accessToken,
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
      final userId = await _authService.getUserId();
      state = state.copyWith(
        userId: userId ?? 'unknown',
        accessToken: token,
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
    final valid = await _authService.checkSessionValidity();
    if (!valid) {
      state = AuthState.unauthenticated();
      return;
    }
    final token = await _authService.getAccessToken();
    final userId = await _authService.getUserId();
    if (token != null && userId != null) {
      state = state.copyWith(
        userId: userId,
        accessToken: token,
        isAuthenticated: true,
      );
    }
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
