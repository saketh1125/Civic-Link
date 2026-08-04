/// Change Password Screen
///
/// Redesigned with shared PasswordField components, grouped card container,
/// and clean error banner / success feedback.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/design/app_decoration.dart';
import '../../core/design/app_spacing.dart';
import '../../main.dart';
import '../../providers/auth_provider.dart';
import '../widgets/auth_guard.dart';
import '../widgets/error_banner.dart';
import '../widgets/glass_card.dart';
import '../widgets/neon_button.dart';
import '../widgets/password_field.dart';
import '../widgets/section_header.dart';

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
        SnackBar(
          content: const Text('Password changed successfully'),
          backgroundColor: context.colors.primary,
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
        appBar: AppBar(
          title: const Text('CHANGE PASSWORD'),
          leading: const BackButton(),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                ErrorBanner(
                  message: _error!,
                  onDismiss: () => setState(() => _error = null),
                ),
                const Gap(AppSpacing.l),
              ],

              // ---- Section header -------------------------------------------
              const SectionHeader(
                'Security',
                padding: EdgeInsets.only(top: 0, bottom: 12),
              ),

              // ---- Card wrapper ------------------------------------------------
              GlassCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Enter your current password and a new password below.',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    const Gap(AppSpacing.xxl),

                    // Current password
                    PasswordField(
                      controller: _currentPasswordController,
                      label: 'Current Password',
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.password],
                    ),
                    const Gap(AppSpacing.l),

                    // New password
                    PasswordField(
                      controller: _newPasswordController,
                      label: 'New Password',
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                    ),
                    const Gap(AppSpacing.l),

                    // Confirm password
                    PasswordField(
                      controller: _confirmPasswordController,
                      label: 'Confirm New Password',
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      onFieldSubmitted: (_) => _onChangePassword(),
                    ),
                  ],
                ),
              ),

              const Gap(AppSpacing.xxl),

              // ---- Submit --------------------------------------------------------
              NeonButton(
                label: 'CHANGE PASSWORD',
                icon: Icons.lock_reset_rounded,
                isLoading: _isLoading,
                onPressed: _onChangePassword,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
