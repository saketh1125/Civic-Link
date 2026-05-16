/// Civic-Link Authentication Service
///
/// Implements Zero-Liability auth handshake using Dio for networking
/// and FlutterSecureStorage for token persistence.
///
/// All email addresses are hashed before transmission.
/// Raw emails NEVER leave the device.
///
/// Usage:
/// ```dart
/// final authService = AuthService(baseUrl: 'http://localhost:8000');
/// final result = await authService.login('officer@police.gov.in', 'password123');
/// if (result.isSuccess) {
///   print('Token stored securely');
/// }
/// ```

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/privacy_crypto.dart';

/// API response wrapper for type-safe error handling
class AuthResult<T> {
  final bool isSuccess;
  final T? data;
  final String? errorMessage;
  final int? statusCode;

  const AuthResult._({
    required this.isSuccess,
    this.data,
    this.errorMessage,
    this.statusCode,
  });

  factory AuthResult.success(T data, {int? statusCode}) {
    return AuthResult._(
      isSuccess: true,
      data: data,
      statusCode: statusCode,
    );
  }

  factory AuthResult.failure(String message, {int? statusCode}) {
    return AuthResult._(
      isSuccess: false,
      errorMessage: message,
      statusCode: statusCode,
    );
  }
}

/// Login response from backend
class LoginResponse {
  final String accessToken;
  final String tokenType;
  final int expiresIn;

  const LoginResponse({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      expiresIn: json['expires_in'] as int? ?? 3600,
    );
  }
}

/// Registration response from backend
class RegisterResponse {
  final String userId;
  final String message;

  const RegisterResponse({
    required this.userId,
    required this.message,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(
      userId: json['id'] as String? ?? json['user_id'] as String? ?? '',
      message: json['message'] as String? ?? 'Registration successful',
    );
  }
}

/// Civic-Link authentication service with Zero-Liability privacy.
///
/// Features:
/// - SHA-256 email hashing before transmission
/// - Secure token storage using FlutterSecureStorage
/// - Comprehensive Dio error handling
/// - Automatic token retrieval for authenticated requests
class AuthService {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  static void Function()? onUnauthorized;

  static const String _tokenKey = 'civic_link_access_token';
  static const String _tokenExpiryKey = 'civic_link_token_expiry';
  static const String _userIdKey = 'civic_link_user_id';

  AuthService({
    required String baseUrl,
    FlutterSecureStorage? storage,
  })  : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'Content-Type': 'application/json'},
        )),
        _secureStorage = storage ?? const FlutterSecureStorage() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await _secureStorage.delete(key: _tokenKey);
            await _secureStorage.delete(key: _tokenExpiryKey);
            await _secureStorage.delete(key: _userIdKey);
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  /// Authenticates user with Zero-Liability email hashing.
  ///
  /// 1. Hashes email locally using SHA-256
  /// 2. Sends ONLY hash + domain + password to backend
  /// 3. Stores returned JWT token securely
  /// 4. Raw email is never transmitted or stored
  ///
  /// Returns [AuthResult] containing [LoginResponse] on success.
  Future<AuthResult<LoginResponse>> login(
    String rawEmail,
    String password,
  ) async {
    try {
      // Zero-Liability: Hash email before transmission
      final hashedEmail = PrivacyCrypto.hashEmail(rawEmail);

      // Build privacy-safe payload
      final payload = {
        'email_hash': hashedEmail.emailHash,
        'email_domain': hashedEmail.emailDomain,
        'password': password,
      };

      // Transmit to backend
      final response = await _dio.post(
        '/api/v1/auth/login/access-token',
        data: payload,
      );

      // Parse successful response
      final loginData = LoginResponse.fromJson(response.data);

      // Extract userId from response if available
      final userId = response.data['user_id'] as String? ??
          response.data['id'] as String?;

      // Securely store the token and userId
      await _storeToken(loginData.accessToken, loginData.expiresIn);
      if (userId != null) {
        await _secureStorage.write(key: _userIdKey, value: userId);
      }

      return AuthResult.success(
        loginData,
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      return _handleDioError(e, 'Login failed');
    } catch (e) {
      return AuthResult.failure('Unexpected error: ${e.toString()}');
    }
  }

  /// Registers new user with Zero-Liability email hashing.
  ///
  /// Sends hashed email + domain to backend.
  /// Raw email never leaves device.
  ///
  /// Additional fields: phone_number, full_name, gender, company_name, employee_id
  Future<AuthResult<RegisterResponse>> register({
    required String rawEmail,
    required String password,
    required String phoneNumber,
    required String fullName,
    required String gender, // 'male' or 'female'
    required String companyName,
    required String employeeId,
  }) async {
    try {
      // Zero-Liability: Hash email before transmission
      final hashedEmail = PrivacyCrypto.hashEmail(rawEmail);

      // Build privacy-safe registration payload
      final payload = {
        'email_hash': hashedEmail.emailHash,
        'email_domain': hashedEmail.emailDomain,
        'password': password,
        'phone_number': phoneNumber,
        'full_name': fullName,
        'gender': gender.toLowerCase(),
        'company_name': companyName,
        'employee_id': employeeId,
      };

      // Transmit to backend
      final response = await _dio.post(
        '/api/v1/auth/register',
        data: payload,
      );

      final registerData = RegisterResponse.fromJson(response.data);

      // Store userId from registration
      await _secureStorage.write(
        key: _userIdKey,
        value: registerData.userId,
      );

      return AuthResult.success(
        registerData,
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      return _handleDioError(e, 'Registration failed');
    } catch (e) {
      return AuthResult.failure('Unexpected error: ${e.toString()}');
    }
  }

  /// Retrieves stored access token for authenticated requests.
  ///
  /// Returns null if no token exists or token has expired.
  Future<String?> getAccessToken() async {
    try {
      final token = await _secureStorage.read(key: _tokenKey);
      final expiryStr = await _secureStorage.read(key: _tokenExpiryKey);

      if (token == null || expiryStr == null) {
        return null;
      }

      // Check token expiry
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry != null && DateTime.now().isAfter(expiry)) {
        // Token expired, clear it
        await logout();
        return null;
      }

      return token;
    } catch (e) {
      return null;
    }
  }

  /// Clears all stored authentication data.
  ///
  /// Call this on logout or token invalidation.
  Future<void> logout() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _tokenExpiryKey);
    await _secureStorage.delete(key: _userIdKey);
  }

  /// Retrieves stored user ID.
  ///
  /// Returns null if no user is logged in.
  Future<String?> getUserId() async {
    try {
      return await _secureStorage.read(key: _userIdKey);
    } catch (e) {
      return null;
    }
  }

  /// Stores token securely with expiration tracking.
  Future<void> _storeToken(String token, int expiresInSeconds) async {
    final expiry = DateTime.now().add(Duration(seconds: expiresInSeconds));

    await _secureStorage.write(key: _tokenKey, value: token);
    await _secureStorage.write(
      key: _tokenExpiryKey,
      value: expiry.toIso8601String(),
    );
  }

  /// Checks if the stored JWT token is still valid by decoding its expiry
  /// claim locally — no network call required.
  ///
  /// Returns true if the token exists and has not expired.
  Future<bool> checkSessionValidity() async {
    try {
      final token = await _secureStorage.read(key: _tokenKey);
      if (token == null || token.isEmpty) return false;

      final expiryStr = await _secureStorage.read(key: _tokenExpiryKey);
      if (expiryStr != null) {
        final expiry = DateTime.tryParse(expiryStr);
        if (expiry != null && DateTime.now().isAfter(expiry)) {
          await logout();
          return false;
        }
      }

      final parts = token.split('.');
      if (parts.length != 3) return false;

      final payload = jsonDecode(
        utf8.decode(base64Url.normalize(parts[1]).codeUnits),
      ) as Map;

      final exp = payload['exp'] as int?;
      if (exp != null) {
        final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        if (DateTime.now().isAfter(expiryDate)) {
          await logout();
          return false;
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Converts DioException to user-friendly error message.
  AuthResult<T> _handleDioError<T>(DioException e, String context) {
    String message;
    int? statusCode = e.response?.statusCode;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'Connection timeout. Please check your network.';
        break;
      case DioExceptionType.connectionError:
        message = 'Cannot connect to server. Please try again later.';
        break;
      case DioExceptionType.badResponse:
        // Handle HTTP status codes
        final responseData = e.response?.data;
        if (responseData is Map && responseData['detail'] != null) {
          message = responseData['detail'] as String;
        } else {
          switch (statusCode) {
            case 400:
              message = 'Invalid request. Please check your information.';
              break;
            case 401:
              message = 'Incorrect email or password.';
              break;
            case 403:
              message = 'Access denied. Domain not authorized.';
              break;
            case 409:
              message = 'Account already exists.';
              break;
            case 422:
              message = 'Validation error. Please check all fields.';
              break;
            case 500:
              message = 'Server error. Please try again later.';
              break;
            default:
              message = '$context (Error ${statusCode ?? 'unknown'})';
          }
        }
        break;
      default:
        message = '$context: ${e.message ?? 'Unknown error'}';
    }

    return AuthResult.failure(message, statusCode: statusCode);
  }
}
