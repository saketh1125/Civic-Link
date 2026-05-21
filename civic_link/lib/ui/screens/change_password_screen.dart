/// Change Password Screen
///
/// Allows authenticated user to change their password.
/// Requires current password verification.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../main.dart';
import '../../providers/auth_provider.dart';
import '../widgets/auth_guard.dart';
import '../widgets/error_banner.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onChangePassword() async {
    final current = _currentPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'All fields are required');
      return;
    }
    if (newPass.length < 8) {
      setState(() => _error = 'New password must be at least 8 characters');
      return;
    }
    if (newPass != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authState = ref.read(authProvider);
      final dio = Dio(BaseOptions(
        baseUrl: kBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          if (authState.accessToken != null)
            'Authorization': 'Bearer ${authState.accessToken}',
        },
      ));

      await dio.post(
        '/api/v1/auth/change-password',
        data: {
          'current_password': current,
          'new_password': newPass,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully'),
          backgroundColor: Color(0xFF00E676),
        ),
      );
      Navigator.of(context).pop();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        ref.read(authProvider.notifier).logout();
        return;
      }
      String message = 'Something went wrong';
      if (e.response?.data is Map && e.response!.data['detail'] != null) {
        message = e.response!.data['detail'] as String;
      }
      setState(() {
        _isLoading = false;
        _error = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      child: Scaffold(
        backgroundColor: kPrimaryBlack,
        appBar: AppBar(
          backgroundColor: kPrimaryBlack,
          elevation: 0,
          title: const Text(
            'CHANGE PASSWORD',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                ErrorBanner(
                  message: _error!,
                  onDismiss: () => setState(() => _error = null),
                ),
                const SizedBox(height: 16),
              ],

              Text(
                'Enter your current password and a new password below.',
                style: TextStyle(color: kHintGrey, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // Current password
              TextField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrent,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  labelStyle: TextStyle(color: kHintGrey),
                  prefixIcon:
                      Icon(Icons.lock_outline, color: kHintGrey),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrent
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: kHintGrey,
                    ),
                    onPressed: () => setState(
                        () => _obscureCurrent = !_obscureCurrent),
                  ),
                  filled: true,
                  fillColor: kInputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // New password
              TextField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: TextStyle(color: kHintGrey),
                  prefixIcon:
                      Icon(Icons.lock_outline, color: kHintGrey),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: kHintGrey,
                    ),
                    onPressed: () => setState(
                        () => _obscureNew = !_obscureNew),
                  ),
                  filled: true,
                  fillColor: kInputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Confirm password
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  labelStyle: TextStyle(color: kHintGrey),
                  prefixIcon:
                      Icon(Icons.lock_outline, color: kHintGrey),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: kHintGrey,
                    ),
                    onPressed: () => setState(
                        () => _obscureConfirm = !_obscureConfirm),
                  ),
                  filled: true,
                  fillColor: kInputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _onChangePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentGreen,
                    foregroundColor: kPrimaryBlack,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: kPrimaryBlack,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'CHANGE PASSWORD',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
