import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:civic_link/providers/auth_provider.dart';
import 'package:civic_link/services/auth_service.dart';

/// Mock AuthService for isolated AuthNotifier testing.
class MockAuthService extends AuthService {
  String? storedUserId;
  String? _storedToken;
  String? _storedRefreshToken;
  bool _tokenExpired = false;

  MockAuthService() : super(baseUrl: 'http://test');

  void setToken(String? token, {bool expired = false}) {
    _storedToken = token;
    _tokenExpired = expired;
  }

  void setRefreshToken(String? token) {
    _storedRefreshToken = token;
  }

  @override
  Future<AuthResult<LoginResponse>> login(String email, String password) async {
    return AuthResult.success(
      LoginResponse(
        accessToken: 'login-token',
        refreshToken: 'login-refresh',
        tokenType: 'bearer',
        expiresIn: 3600,
      ),
    );
  }

  @override
  Future<String?> getAccessToken() async {
    if (_tokenExpired) return null;
    return _storedToken;
  }

  @override
  Future<String?> getRefreshToken() async => _storedRefreshToken;

  @override
  Future<String?> getUserId() async => storedUserId;

  @override
  Future<String?> refreshToken() async {
    if (_storedRefreshToken == null) return null;
    _storedToken = 'refreshed-token';
    _storedRefreshToken = 'refreshed-refresh';
    return _storedToken;
  }

  @override
  Future<bool> checkSessionValidity() async {
    return _storedToken != null && !_tokenExpired;
  }

  @override
  Future<void> logout() async {
    _storedToken = null;
    _storedRefreshToken = null;
    storedUserId = null;
  }
}

void main() {
  group('AuthNotifier', () {
    late ProviderContainer container;
    late AuthNotifier notifier;
    late MockAuthService mockService;

    setUp(() {
      mockService = MockAuthService();
      container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(mockService),
        ],
      );
      notifier = container.read(authProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is unauthenticated', () {
      final state = container.read(authProvider);
      expect(state.isAuthenticated, false);
      expect(state.userId, isNull);
      expect(state.accessToken, isNull);
      expect(state.refreshToken, isNull);
    });

    test('login sets authenticated state', () async {
      mockService.storedUserId = 'test-user';

      final result = await notifier.login('test@test.com', 'Password123');

      expect(result.isSuccess, true);
      final state = container.read(authProvider);
      expect(state.isAuthenticated, true);
      expect(state.accessToken, 'login-token');
      expect(state.refreshToken, 'login-refresh');
    });

    test('logout clears state', () async {
      mockService.storedUserId = 'test-user';
      await notifier.login('test@test.com', 'Password123');
      expect(container.read(authProvider).isAuthenticated, true);

      await notifier.logout();

      final state = container.read(authProvider);
      expect(state.isAuthenticated, false);
      expect(state.userId, isNull);
      expect(state.accessToken, isNull);
      expect(state.refreshToken, isNull);
    });

    test('checkSessionValidity returns false for expired token', () async {
      mockService.setToken('expired-token', expired: true);

      final valid = await notifier.checkSessionValidity();
      expect(valid, false);
    });

    test('checkSessionValidity returns true for valid token', () async {
      mockService.setToken('valid-token');

      final valid = await notifier.checkSessionValidity();
      expect(valid, true);
    });

    test('restoreSession restores from stored tokens', () async {
      mockService.storedUserId = 'restored-user';
      mockService.setToken('valid-token');
      mockService.setRefreshToken('restored-refresh');

      await notifier.restoreSession();

      final state = container.read(authProvider);
      expect(state.isAuthenticated, true);
      expect(state.userId, 'restored-user');
      expect(state.accessToken, isNotNull);
      expect(state.refreshToken, 'restored-refresh');
    });

    test('restoreSession returns unauthenticated when no tokens', () async {
      mockService.storedUserId = null;
      mockService.setToken(null);

      await notifier.restoreSession();

      final state = container.read(authProvider);
      expect(state.isAuthenticated, false);
    });
  });
}
