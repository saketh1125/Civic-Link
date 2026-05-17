import 'package:civic_link/providers/auth_provider.dart';
import 'package:civic_link/providers/civic_score_provider.dart';
import 'package:civic_link/services/auth_service.dart';

// =============================================================================
// Fake Auth Notifier — extends AuthNotifier for Riverpod 3 type compatibility
// =============================================================================

class FakeAuthNotifier extends AuthNotifier {
  AuthResult<LoginResponse>? _loginResult;
  bool _sessionValid = true;
  bool _preAuthenticated = false;

  @override
  AuthState build() {
    if (_preAuthenticated) {
      return const AuthState(
        userId: 'test-user',
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
        isAuthenticated: true,
      );
    }
    return AuthState.unauthenticated();
  }

  void setPreAuthenticated() {
    _preAuthenticated = true;
  }

  void setLoginResult(AuthResult<LoginResponse> result) {
    _loginResult = result;
  }

  void setSessionValid(bool valid) {
    _sessionValid = valid;
  }

  @override
  Future<AuthResult<LoginResponse>> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 50));
    if (_loginResult != null && _loginResult!.isSuccess) {
      state = AuthState(
        userId: 'test-user',
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
        isAuthenticated: true,
      );
    }
    return _loginResult ??
        AuthResult.failure('Login failed', statusCode: 401);
  }

  @override
  Future<void> restoreSession() async {
    state = const AuthState(
      userId: 'test-user',
      accessToken: 'test-access-token',
      refreshToken: 'test-refresh-token',
      isAuthenticated: true,
    );
  }

  @override
  Future<bool> checkSessionValidity() async => _sessionValid;

  @override
  Future<void> logout() async {
    state = AuthState.unauthenticated();
  }
}

// =============================================================================
// Fake Civic Score Notifier — extends CivicScoreNotifier for type compatibility
// =============================================================================

class FakeCivicScoreNotifier extends CivicScoreNotifier {
  @override
  CivicScoreState build() => CivicScoreState.initial();

  void setScore(double score) {
    state = state.copyWith(currentScore: score);
  }

  @override
  Future<void> startTelemetry({
    required String baseUrl,
    required String userId,
    required String authToken,
    String? matchId,
  }) async {}

  @override
  Future<void> stopTelemetry() async {}

  @override
  void updateScore(double newScore) {
    final clamped = newScore.clamp(0.0, 100.0);
    state = state.copyWith(currentScore: clamped);
  }

  @override
  void reset() {
    state = CivicScoreState.initial();
  }

  @override
  void setHistory(List<double> scores) {
    if (scores.isEmpty) {
      reset();
      return;
    }
    state = state.copyWith(
      currentScore: scores.last,
      scoreHistory: scores.reversed.toList(),
    );
  }
}
